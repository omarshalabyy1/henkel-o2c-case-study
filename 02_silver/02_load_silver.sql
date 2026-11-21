/*
===============================================================================
Load Silver (Bronze -> Silver)
===============================================================================
Script Purpose:
    Fills the silver tables created by 01_ddl_silver.sql from the bronze
    tables (src_*, never changed).
    - Each SAP field is renamed to the words of its schema comment.
    - 'select distinct' drops a row loaded twice (same values in every column).
    - Two DIFFERENT rows with the same key break the PRIMARY KEY and stop the
      load: the source gives no rule for which version wins.
    - Parents are loaded before children (the FOREIGN KEYS need them).
    'insert into ... by name' matches columns by name, not by position.

Usage:
    python run_sql.py   (runs 01_ddl_silver.sql, then this file, then the checks)
===============================================================================
*/

-- =============================================================================
-- Master data
-- =============================================================================

insert into silver.sales_organizations by name
select distinct
    vkorg as sales_organization_key,
    vtext as description
from src_tvkot;

insert into silver.distribution_channels by name
select distinct
    vtweg as distribution_channel_key,
    vtext as description
from src_tvtwt;

insert into silver.plants by name
select distinct
    werks as plant_key,
    name1 as plant_name,
    land1 as country
from src_t001w;

insert into silver.rejection_reasons by name
select distinct
    abgru as rejection_reason_code,
    bezei as description
from src_tvagt;

insert into silver.customers by name
select distinct
    kunnr as customer_number,
    name1 as customer_name,
    land1 as country,
    regio as region_state,
    ktokd as account_group
from src_kna1;

insert into silver.materials by name
select distinct
    matnr as material_number,
    matkl as material_group,              -- HAIRPRO / ADHESIV
    meins as base_unit_of_measure,
    mtart as material_type                -- FERT = finished
from src_mara;

insert into silver.material_names by name
select distinct
    matnr as material_number,
    maktx as material_description
from src_makt
where spras = 'EN';


-- =============================================================================
-- Sales order
-- =============================================================================

insert into silver.orders by name
select distinct
    vbeln as sales_order_number,
    erdat as order_creation_date,
    auart as order_type,                  -- TA = standard, KR = credit memo request, RE = returns
    kunnr as sold_to_customer,
    vkorg as sales_organization,
    vtweg as distribution_channel,
    spart as division,                    -- HA = Hair, AD = Adhesives
    netwr as net_order_value,             -- active items only
    waerk as document_currency,
    vdatu as customer_requested_delivery_date
from src_vbak;

insert into silver.order_lines by name
select distinct
    vbeln as sales_order_number,
    posnr as item_number,
    matnr as material_number,
    kwmeng as ordered_quantity,
    meins as unit_of_measure,
    netpr as net_price_per_uom,
    kwmeng * netpr as line_value,         -- added: quantity x price (the KR line is 20 x -25.00 = -500)
    waerk as currency,
    werks as delivering_plant,
    pstyv as item_category,               -- TAN = standard, KRN = credit memo, TANN = free item
    nullif(abgru, '') as rejection_reason,          -- blank = no reason (schema line 164)
    coalesce(abgru, '') <> '' as is_rejected        -- added: blank or NULL reason = active line
from src_vbap;


-- =============================================================================
-- Outbound delivery
-- =============================================================================

insert into silver.deliveries by name
select distinct
    vbeln as delivery_number,
    erdat as delivery_creation_date,
    wadat_ist as actual_goods_issue_date, -- NULL if goods not yet issued
    kunnr as ship_to_customer,
    vstel as shipping_point
from src_likp;

insert into silver.delivery_lines by name
select distinct
    vbeln as delivery_number,
    posnr as delivery_item_number,
    matnr as material_number,
    lfimg as delivered_quantity,          -- for THIS delivery item, not cumulative
    meins as unit_of_measure,             -- schema: "UOM"
    werks as plant,
    vgbel as originating_sales_order,     -- the order line this delivery line ships
    vgpos as originating_sales_order_item
from src_lips;


-- =============================================================================
-- Billing document
-- =============================================================================

insert into silver.billing_docs by name
select distinct
    vbeln as billing_document_number,
    erdat as creation_date,
    fkart as billing_type,                -- F2 = invoice, G2 = credit memo, S1 = cancellation
    kunrg as payer_customer,
    waerk as document_currency,
    netwr as net_billing_value,           -- negative for credit memos and cancellations
    mwsbp as tax_amount,
    fkdat as billing_date,                -- use for revenue, not erdat
    vkorg as sales_organization
from src_vbrk;

-- left join: a line with no header keeps its row, and the FOREIGN KEY stops the load
insert into silver.billing_lines by name
select distinct
    p.vbeln as billing_document_number,
    p.posnr as billing_item_number,
    p.matnr as material_number,
    -- negative for credit memos (schema line 225; arrived +20) and cancellations (our assumption)
    case
        when k.fkart in ('G2', 'S1') then -abs(p.fkimg)
        else p.fkimg
    end as billed_quantity,
    p.meins as unit_of_measure,             -- schema: "UOM"
    p.netwr as item_net_value,              -- negative for credit memos and cancellations
    p.aubel as originating_sales_order,     -- the order line this billing line bills
    p.aupos as originating_sales_order_item,
    p.vgbel as context_dependent_reference, -- F2: a delivery, G2: the original invoice
    p.vgpos as reference_item_number        -- schema: "Reference item number within the vgbel document"
from src_vbrp p
left join src_vbrk k on k.vbeln = p.vbeln;


-- =============================================================================
-- Accounts receivable
-- =============================================================================

insert into silver.open_items by name
select distinct
    bukrs as company_code,
    kunnr as customer_number,
    belnr as fi_document_number,
    gjahr as fiscal_year,
    buzei as line_item_number,
    bldat as fi_document_posting_date,
    faedt as net_due_date,
    wrbtr as amount_in_document_currency, -- net amount, no tax
    waers as currency,
    rebzg as reference_billing_document
from src_bsid;

insert into silver.cleared_items by name
select distinct
    bukrs as company_code,
    kunnr as customer_number,
    belnr as fi_document_number,
    gjahr as fiscal_year,
    buzei as line_item_number,
    bldat as fi_document_posting_date,
    faedt as net_due_date,                -- schema here: "Original due date" (same field faedt)
    augdt as clearing_date,               -- paid (or offset, for the credit memo)
    wrbtr as amount_in_document_currency,
    waers as currency,
    rebzg as reference_billing_document
from src_bsad;


-- =============================================================================
-- Prepared tables: sum before joining (3,000 would show as 12,000 otherwise)
-- =============================================================================

-- shipped per order line: only deliveries whose goods have left
insert into silver.shipped_per_line by name
select
    dl.originating_sales_order as sales_order_number,
    dl.originating_sales_order_item as item_number,
    sum(dl.delivered_quantity) as shipped_quantity,
    max(d.actual_goods_issue_date) as last_goods_issue_date
from silver.delivery_lines dl
join silver.deliveries d on d.delivery_number = dl.delivery_number
where d.actual_goods_issue_date is not null
group by dl.originating_sales_order, dl.originating_sales_order_item;

-- billed per order line (quantity and value already carry the right sign)
insert into silver.billed_per_line by name
select
    originating_sales_order as sales_order_number,
    originating_sales_order_item as item_number,
    sum(billed_quantity) as billed_quantity,
    sum(item_net_value) as billed_net_value
from silver.billing_lines
group by originating_sales_order, originating_sales_order_item;

-- receivables, part 1: every cleared item
insert into silver.receivables by name
select
    c.*,
    false as is_open
from silver.cleared_items c;

-- receivables, part 2: open items not already in the cleared list
-- (an item in both lists is stopped by a silver check, schema line 248)
insert into silver.receivables by name
select
    o.*,
    true as is_open
from silver.open_items o
where not exists (
    select 1 from silver.cleared_items c
    where c.company_code = o.company_code
      and c.fi_document_number = o.fi_document_number
      and c.fiscal_year = o.fiscal_year
      and c.line_item_number = o.line_item_number
);
