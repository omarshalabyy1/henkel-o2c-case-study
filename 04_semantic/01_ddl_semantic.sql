/*
===============================================================================
DDL Script: Create Semantic Tables (the star schema)
===============================================================================
Script Purpose:
    Creates the 'semantic' schema: the star schema the analytical layer reads
    (Kimball: 3 facts sharing conformed dimensions; every join is one hop).
    Every source table lands in a fact or a dimension:
      facts:      vbak + vbap + likp + lips + vbrp -> fact_order_line
                  vbrk + bsid + bsad               -> fact_receivable
                  vbrp + vbrk + vbak (division)    -> fact_billing_line
      dimensions: kna1 -> dim_customer, mara + makt -> dim_material,
                  tvkot -> dim_sales_organization, tvtwt -> dim_distribution_channel,
                  t001w -> dim_plant, tvagt -> dim_rejection_reason, + dim_date
    Keys = the source schema's PK / FK (lines 19-71) plus the order's channel
    -> tvtwt (implied, not listed), declared here, so DuckDB
    refuses a fact row that points to a missing dimension row.
    fact_order_line and fact_receivable are accumulating snapshots as of
    2026-05-04: one row per order line / billing document, with one date FK per
    milestone (NULL until reached). fact_billing_line is a transaction fact:
    one row per billing line, on its billing date. It links 1:N to both other
    facts, so every relationship in the model is one-to-many.
    Natural keys (no surrogate keys) and current values only (SCD type 1):
    the extract is one snapshot with no history.

Usage:
    python run_sql.py   (runs gold and its checks, then this file)
===============================================================================
*/

drop schema if exists semantic cascade;
create schema semantic;


-- =============================================================================
-- Dimensions
-- =============================================================================

-- dim_date: one row per day, from the earliest to the latest date in the facts
-- (filled by 02_load_semantic.sql, so it grows with the data)
create table semantic.dim_date (
    date_key       date        primary key,
    year           integer,
    quarter        integer,
    month          integer,
    month_name     varchar,
    year_month     varchar,      -- e.g. 2025-10, for monthly charts
    day_of_month   integer,
    weekday_name   varchar
);

-- dim_customer: one row per customer (kna1)
create table semantic.dim_customer (
    customer_number  varchar  primary key,
    customer_name    varchar,
    country          varchar,
    region_state     varchar
);

-- dim_material: one row per material (mara + English makt, merged: no snowflake)
create table semantic.dim_material (
    material_number       varchar  primary key,
    material_description  varchar,
    material_group        varchar,      -- HAIRPRO / ADHESIV
    material_type         varchar,
    base_unit_of_measure  varchar
);

-- dim_sales_organization: one row per sales organization (tvkot)
create table semantic.dim_sales_organization (
    sales_organization_key  varchar  primary key,
    description             varchar
);

-- dim_distribution_channel: one row per distribution channel (tvtwt)
create table semantic.dim_distribution_channel (
    distribution_channel_key  varchar  primary key,
    description               varchar
);

-- dim_plant: one row per plant (t001w)
create table semantic.dim_plant (
    plant_key   varchar  primary key,
    plant_name  varchar,
    country     varchar
);

-- dim_rejection_reason: one row per rejection reason (tvagt)
create table semantic.dim_rejection_reason (
    rejection_reason_code  varchar  primary key,
    description            varchar
);


-- =============================================================================
-- Facts
-- =============================================================================

-- fact_order_line: one row per order line (grain: vbap vbeln + posnr)
-- additive: quantities (within one unit_of_measure) and values (within one currency)
-- non-additive: net_price_per_uom, days_late (average or max, never sum)
create table semantic.fact_order_line (
    sales_order_number                varchar        not null,
    item_number                       varchar        not null,
    order_type                        varchar,
    order_creation_date               date           not null references semantic.dim_date (date_key),
    sold_to_customer                  varchar        not null references semantic.dim_customer (customer_number),
    sales_organization                varchar        not null references semantic.dim_sales_organization (sales_organization_key),
    distribution_channel              varchar        not null references semantic.dim_distribution_channel (distribution_channel_key),
    delivering_plant                  varchar        not null references semantic.dim_plant (plant_key),
    currency                          varchar,
    division                          varchar,       -- degenerate: no division table in the source
    material_number                   varchar        not null references semantic.dim_material (material_number),
    ordered_quantity                  decimal(13, 3),
    unit_of_measure                   varchar,
    net_price_per_uom                 decimal(11, 2),
    line_value                        decimal(15, 2),
    rejection_reason                  varchar        references semantic.dim_rejection_reason (rejection_reason_code),  -- NULL = not rejected
    is_rejected                       boolean,
    customer_requested_delivery_date  date           references semantic.dim_date (date_key),  -- NULL for the credit memo request
    shipped_quantity                  decimal(18, 3),
    last_goods_issue_date             date           references semantic.dim_date (date_key),  -- NULL if not shipped
    billed_quantity                   decimal(18, 3),
    billed_net_value                  decimal(18, 2),
    is_active_ta                      boolean,
    open_to_ship_quantity             decimal(18, 3),
    open_to_ship_value                decimal(18, 2),
    delivered_not_billed_value        decimal(18, 2),
    days_late                         bigint,
    is_on_time                        boolean,
    is_past_due_unshipped             boolean,
    primary key (sales_order_number, item_number)
);

-- fact_receivable: one row per billing document (grain: vbrk vbeln)
-- additive: values within one currency; non-additive: days_overdue, days_to_pay
create table semantic.fact_receivable (
    billing_document_number      varchar        primary key,
    billing_type                 varchar,
    billing_date                 date           not null references semantic.dim_date (date_key),
    payer_customer               varchar        not null references semantic.dim_customer (customer_number),
    sales_organization           varchar        not null references semantic.dim_sales_organization (sales_organization_key),
    document_currency            varchar,
    net_billing_value            decimal(15, 2),
    company_code                 varchar,
    fi_document_number           varchar,
    amount_in_document_currency  decimal(15, 2),
    tax_amount                   decimal(15, 2),
    net_due_date                 date           references semantic.dim_date (date_key),
    clearing_date                date           references semantic.dim_date (date_key),
    is_open                      boolean,
    days_overdue                 bigint,
    days_to_pay                  bigint,
    is_offset                    boolean,
    has_ar_item                  boolean
);

-- fact_billing_line: one row per billing line (grain: vbrp vbeln + posnr)
-- revenue by billing month x material / division (schema line 214: revenue date = fkdat)
-- additive: item_net_value (within one currency), billed_quantity (within one unit_of_measure)
-- sits between the two other facts, so no many-to-many is left (schema lines 54-57):
--   fact_order_line 1 -> N fact_billing_line N <- 1 fact_receivable
--   (one order line can be billed by several billing lines; one billing document has several lines)
create table semantic.fact_billing_line (
    billing_document_number       varchar        not null references semantic.fact_receivable (billing_document_number),
    billing_item_number           varchar        not null,
    billing_type                  varchar,
    billing_date                  date           not null references semantic.dim_date (date_key),
    payer_customer                varchar        not null references semantic.dim_customer (customer_number),
    sales_organization            varchar        not null references semantic.dim_sales_organization (sales_organization_key),
    document_currency             varchar,
    division                      varchar,       -- degenerate: the order's division, no division table in the source
    material_number               varchar        not null references semantic.dim_material (material_number),
    billed_quantity               decimal(13, 3),  -- negative for credit memos and cancellations
    unit_of_measure               varchar,
    item_net_value                decimal(15, 2),
    originating_sales_order       varchar        not null,  -- the order line this billing line bills
    originating_sales_order_item  varchar        not null,
    context_dependent_reference   varchar,       -- degenerate: F2 the delivery, G2 the invoice it reverses (schema lines 60-63)
    reference_item_number         varchar,
    primary key (billing_document_number, billing_item_number),
    foreign key (originating_sales_order, originating_sales_order_item)
        references semantic.fact_order_line (sales_order_number, item_number)
);
