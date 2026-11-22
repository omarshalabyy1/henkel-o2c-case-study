/*
===============================================================================
Silver tables: one per source table, with its keys
===============================================================================
- Columns renamed to their schema comments (snake_case), types unchanged.
- PRIMARY and FOREIGN KEYs from 01_source_schema.sql: DuckDB refuses a
  duplicate key, a NULL key or a missing parent.
- Two exceptions: makt is keyed on matnr only (English names only), and
  vbrp.vgbel has no FK (its target depends on the billing type; a check tests it).
- Dropped and rebuilt every run.

Run: python run_sql.py
===============================================================================
*/

drop schema if exists silver cascade;
create schema silver;


-- =============================================================================
-- Master data (parents first: other tables point to these)
-- =============================================================================

-- Sales organizations (tvkot)
create table silver.sales_organizations (
    sales_organization_key  varchar(4)  primary key,
    description             varchar(60)
);

-- Distribution channels (tvtwt)
create table silver.distribution_channels (
    distribution_channel_key  varchar(2)  primary key,
    description               varchar(60)
);

-- Plants (t001w)
create table silver.plants (
    plant_key   varchar(4)  primary key,
    plant_name  varchar(60),
    country     varchar(3)
);

-- Rejection reason codes (tvagt)
create table silver.rejection_reasons (
    rejection_reason_code  varchar(2)  primary key,
    description            varchar(40)
);

-- Customers (kna1)
create table silver.customers (
    customer_number  varchar(10)  primary key,
    customer_name    varchar(60),
    country          varchar(3),
    region_state     varchar(3),
    account_group    varchar(4)
);

-- Materials (mara)
create table silver.materials (
    material_number       varchar(18)  primary key,
    material_group        varchar(9),
    base_unit_of_measure  varchar(3),
    material_type         varchar(4)
);

-- Material descriptions (makt), English only: one row per material
create table silver.material_names (
    material_number       varchar(18)  primary key references silver.materials (material_number),
    material_description  varchar(40)
);


-- =============================================================================
-- Sales order (vbak, vbap)
-- =============================================================================

create table silver.orders (
    sales_order_number                varchar(10)  primary key,
    order_creation_date               date,
    order_type                        varchar(4),
    sold_to_customer                  varchar(10)  not null references silver.customers (customer_number),
    sales_organization                varchar(4)   not null references silver.sales_organizations (sales_organization_key),
    distribution_channel              varchar(2),
    division                          varchar(2),
    net_order_value                   decimal(15, 2),
    document_currency                 varchar(5),
    customer_requested_delivery_date  date
);

create table silver.order_lines (
    sales_order_number  varchar(10)  not null references silver.orders (sales_order_number),
    item_number         varchar(6)   not null,
    material_number     varchar(18)  not null references silver.materials (material_number),
    ordered_quantity    decimal(13, 3),
    unit_of_measure     varchar(3),
    net_price_per_uom   decimal(11, 2),
    line_value          decimal(15, 2),         -- added: quantity x price (the KR line is -500)
    currency            varchar(5),
    delivering_plant    varchar(4)   not null references silver.plants (plant_key),
    item_category       varchar(4),
    rejection_reason    varchar(2)   references silver.rejection_reasons (rejection_reason_code),  -- nullable (schema line 38)
    is_rejected         boolean,                -- added: blank or NULL reason = active line
    primary key (sales_order_number, item_number)
);


-- =============================================================================
-- Outbound delivery (likp, lips)
-- =============================================================================

create table silver.deliveries (
    delivery_number          varchar(10)  primary key,
    delivery_creation_date   date,
    actual_goods_issue_date  date,          -- NULL if goods not yet issued
    ship_to_customer         varchar(10)  not null references silver.customers (customer_number),
    shipping_point           varchar(4)
);

create table silver.delivery_lines (
    delivery_number               varchar(10)  not null references silver.deliveries (delivery_number),
    delivery_item_number          varchar(6)   not null,
    material_number               varchar(18)  not null references silver.materials (material_number),
    delivered_quantity            decimal(13, 3),
    unit_of_measure               varchar(3),
    plant                         varchar(4)   not null references silver.plants (plant_key),
    originating_sales_order       varchar(10)  not null,
    originating_sales_order_item  varchar(6)   not null,
    primary key (delivery_number, delivery_item_number),
    foreign key (originating_sales_order, originating_sales_order_item)
        references silver.order_lines (sales_order_number, item_number)
);


-- =============================================================================
-- Billing document (vbrk, vbrp)
-- =============================================================================

create table silver.billing_docs (
    billing_document_number  varchar(10)  primary key,
    creation_date            date,
    billing_type             varchar(4),
    payer_customer           varchar(10)  not null references silver.customers (customer_number),
    document_currency        varchar(5),
    net_billing_value        decimal(15, 2),
    tax_amount               decimal(15, 2),
    billing_date             date,
    sales_organization       varchar(4)   not null references silver.sales_organizations (sales_organization_key)
);

create table silver.billing_lines (
    billing_document_number       varchar(10)  not null references silver.billing_docs (billing_document_number),
    billing_item_number           varchar(6)   not null,
    material_number               varchar(18)  not null references silver.materials (material_number),
    billed_quantity               decimal(13, 3),  -- negative for credit memos and cancellations
    unit_of_measure               varchar(3),
    item_net_value                decimal(15, 2),
    originating_sales_order       varchar(10)  not null,
    originating_sales_order_item  varchar(6)   not null,
    context_dependent_reference   varchar(10),  -- F2: a delivery, G2: the original invoice (no FK: it depends on billing_type; a silver check tests it)
    reference_item_number         varchar(6),
    primary key (billing_document_number, billing_item_number),
    foreign key (originating_sales_order, originating_sales_order_item)
        references silver.order_lines (sales_order_number, item_number)
);


-- =============================================================================
-- Accounts receivable (bsid open, bsad cleared)
-- =============================================================================

create table silver.open_items (
    company_code                 varchar(4)   not null,
    customer_number              varchar(10)  not null references silver.customers (customer_number),
    fi_document_number           varchar(10)  not null,
    fiscal_year                  integer      not null,
    line_item_number             varchar(3)   not null,
    fi_document_posting_date     date,
    net_due_date                 date,
    amount_in_document_currency  decimal(15, 2),
    currency                     varchar(5),
    reference_billing_document   varchar(10)  not null references silver.billing_docs (billing_document_number),
    primary key (company_code, fi_document_number, fiscal_year, line_item_number)
);

create table silver.cleared_items (
    company_code                 varchar(4)   not null,
    customer_number              varchar(10)  not null references silver.customers (customer_number),
    fi_document_number           varchar(10)  not null,
    fiscal_year                  integer      not null,
    line_item_number             varchar(3)   not null,
    fi_document_posting_date     date,
    net_due_date                 date,          -- schema here: "Original due date" (same field faedt)
    clearing_date                date,
    amount_in_document_currency  decimal(15, 2),
    currency                     varchar(5),
    reference_billing_document   varchar(10)  not null references silver.billing_docs (billing_document_number),
    primary key (company_code, fi_document_number, fiscal_year, line_item_number)
);


-- =============================================================================
-- Prepared tables (sums before joining; one receivables list)
-- =============================================================================

-- shipped per order line (only deliveries with a goods issue date)
create table silver.shipped_per_line (
    sales_order_number     varchar(10)  not null,
    item_number            varchar(6)   not null,
    shipped_quantity       decimal(18, 3),
    last_goods_issue_date  date,
    primary key (sales_order_number, item_number),
    foreign key (sales_order_number, item_number) references silver.order_lines (sales_order_number, item_number)
);

-- billed per order line (sums of billing_lines)
create table silver.billed_per_line (
    sales_order_number  varchar(10)  not null,
    item_number         varchar(6)   not null,
    billed_quantity     decimal(18, 3),
    billed_net_value    decimal(18, 2),
    primary key (sales_order_number, item_number),
    foreign key (sales_order_number, item_number) references silver.order_lines (sales_order_number, item_number)
);

-- receivables: cleared + open items, each item once
create table silver.receivables (
    company_code                 varchar(4)   not null,
    customer_number              varchar(10)  not null references silver.customers (customer_number),
    fi_document_number           varchar(10)  not null,
    fiscal_year                  integer      not null,
    line_item_number             varchar(3)   not null,
    fi_document_posting_date     date,
    net_due_date                 date,
    clearing_date                date,          -- NULL = still open
    amount_in_document_currency  decimal(15, 2),
    currency                     varchar(5),
    reference_billing_document   varchar(10)  not null references silver.billing_docs (billing_document_number),
    is_open                      boolean,
    primary key (company_code, fi_document_number, fiscal_year, line_item_number)
);
