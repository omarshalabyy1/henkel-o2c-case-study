/*
===============================================================================
Load Gold (Silver -> Gold)
===============================================================================
Script Purpose:
    Creates the 'gold' schema as TABLES: the business rules (open to ship,
    delivered not billed, days late, days overdue, days to pay ...) on top of
    silver, one row per order line / billing document / billing line / customer / material.
    Rebuilt in full each run; the gold checks then test the stored rows.
    The semantic layer (04_semantic) turns these into the star schema.
    Columns taken from silver keep their schema-comment names; the added
    columns (shipped, billed, open to ship, days late ...) say what they compute.
    "Today" = 2026-05-04, the extract date stated in 02_sample_data.sql.
    Money is never added across currencies: every row carries its currency.

Usage:
    python run_sql.py   (runs silver and its checks, then this file, then the gold checks)
===============================================================================
*/

drop schema if exists gold cascade;
create schema gold;


-- gold.order_lines: one row per order line, with the order line business rules
create table gold.order_lines as
with lines as (
    -- order line + its order header + material + shipped and billed totals
    -- left joins: an order line is never dropped; missing totals become 0
    select
        l.sales_order_number,
        l.item_number,
        o.order_type,
        o.order_creation_date,
        o.sold_to_customer,
        o.sales_organization,
        o.distribution_channel,
        l.delivering_plant,
        l.currency,
        o.division,
        l.material_number,
        l.ordered_quantity,
        l.unit_of_measure,                  -- quantities add up only within one unit
        l.net_price_per_uom,                -- source signs: the KR line is 20 x -25.00 = -500 (data line 243)
        l.line_value,
        l.rejection_reason,
        l.is_rejected,
        o.customer_requested_delivery_date,
        coalesce(s.shipped_quantity, 0) as shipped_quantity,
        s.last_goods_issue_date,
        coalesce(b.billed_quantity, 0) as billed_quantity,
        coalesce(b.billed_net_value, 0) as billed_net_value,
        -- active standard line = TA order, not rejected
        o.order_type = 'TA' and l.is_rejected = false as is_active_ta
    from silver.order_lines l
    left join silver.orders o on o.sales_order_number = l.sales_order_number
    left join silver.shipped_per_line s on s.sales_order_number = l.sales_order_number and s.item_number = l.item_number
    left join silver.billed_per_line b on b.sales_order_number = l.sales_order_number and b.item_number = l.item_number
)
select
    *,
    -- open to ship = ordered but not shipped yet (active TA lines only)
    -- greatest(..., 0): an over-delivery leaves nothing open, never a negative backlog
    case when is_active_ta then greatest(ordered_quantity - shipped_quantity, 0) else 0 end as open_to_ship_quantity,
    case when is_active_ta then round(greatest(ordered_quantity - shipped_quantity, 0) * net_price_per_uom, 2) else 0 end as open_to_ship_value,
    -- delivered not billed = shipped but no invoice yet (active TA lines, only when shipped > billed)
    case when is_active_ta and shipped_quantity > billed_quantity then round((shipped_quantity - billed_quantity) * net_price_per_uom, 2) else 0 end as delivered_not_billed_value,
    -- days late = last goods issue minus requested delivery date (empty if not shipped)
    last_goods_issue_date - customer_requested_delivery_date as days_late,
    -- on time = active TA line fully shipped by the requested date (data lines 103, 116 judge each delivery); empty until fully shipped
    case when is_active_ta and shipped_quantity >= ordered_quantity then last_goods_issue_date <= customer_requested_delivery_date end as is_on_time,
    -- due before today and not fully shipped
    is_active_ta and shipped_quantity < ordered_quantity and customer_requested_delivery_date < date '2026-05-04' as is_past_due_unshipped
from lines
order by sales_order_number, item_number;


-- gold.receivables: one row per billing document, with the receivable business rules
-- billing doc left join receivable: a billing doc with no AR item is kept (has_ar_item = false)
create table gold.receivables as
select
    d.billing_document_number,
    d.billing_type,
    d.billing_date,
    d.payer_customer,
    d.sales_organization,
    d.document_currency,
    d.net_billing_value,              -- revenue on the billing date (schema lines 212, 214)
    r.company_code,
    r.fi_document_number,
    r.amount_in_document_currency,  -- AR holds the net amount (no tax)
    d.tax_amount,
    r.net_due_date,
    r.clearing_date,
    coalesce(r.is_open, false) as is_open,
    -- days past the due date, open items only (negative = not due yet)
    case when r.is_open then date '2026-05-04' - r.net_due_date end as days_overdue,
    -- days from billing to payment, invoices (F2) only: the credit memo is offset, not paid
    case when d.billing_type = 'F2' then r.clearing_date - d.billing_date end as days_to_pay,
    d.billing_type = 'G2' and r.clearing_date is not null as is_offset,
    r.reference_billing_document is not null as has_ar_item
from silver.billing_docs d
left join silver.receivables r on r.reference_billing_document = d.billing_document_number
order by d.billing_document_number;


-- gold.billing_lines: one row per billing line (vbrp), with its header and order division
-- revenue on the billing date (schema line 214), split by material and division
create table gold.billing_lines as
select
    bl.billing_document_number,
    bl.billing_item_number,
    d.billing_type,
    d.billing_date,
    d.payer_customer,
    d.sales_organization,
    d.document_currency,
    o.division,                       -- the order's division (vbak spart): vbrp has none
    bl.material_number,
    bl.billed_quantity,               -- negative for credit memos and cancellations (fixed in silver)
    bl.unit_of_measure,
    bl.item_net_value,                -- value already has the right sign (schema line 227)
    bl.originating_sales_order,
    bl.originating_sales_order_item,
    bl.context_dependent_reference,   -- F2: the delivery, G2: the invoice it reverses (schema lines 60-63)
    bl.reference_item_number
from silver.billing_lines bl
join silver.billing_docs d on d.billing_document_number = bl.billing_document_number
join silver.orders o on o.sales_order_number = bl.originating_sales_order
order by bl.billing_document_number, bl.billing_item_number;


-- gold.customers: one row per customer
create table gold.customers as
select
    customer_number,
    customer_name,
    country,
    region_state
from silver.customers
order by customer_number;


-- gold.materials: one row per material, with its English description
create table gold.materials as
select
    m.material_number,
    n.material_description,
    m.material_group,
    m.material_type,
    m.base_unit_of_measure
from silver.materials m
left join silver.material_names n on n.material_number = m.material_number
order by m.material_number;


-- gold.sales_organizations: one row per sales organization (tvkot)
create table gold.sales_organizations as
select sales_organization_key, description
from silver.sales_organizations
order by sales_organization_key;


-- gold.distribution_channels: one row per distribution channel (tvtwt)
create table gold.distribution_channels as
select distribution_channel_key, description
from silver.distribution_channels
order by distribution_channel_key;


-- gold.plants: one row per plant (t001w)
create table gold.plants as
select plant_key, plant_name, country
from silver.plants
order by plant_key;


-- gold.rejection_reasons: one row per rejection reason (tvagt)
create table gold.rejection_reasons as
select rejection_reason_code, description
from silver.rejection_reasons
order by rejection_reason_code;
