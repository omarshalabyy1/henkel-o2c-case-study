/*
===============================================================================
Sales mart
===============================================================================
What customers ordered, cancelled and returned, and revenue by division.
Reads only the star schema. Money per currency. "Today" = 2026-05-04.

Run: python run_sql.py
===============================================================================
*/

drop schema if exists mart_sales cascade;
create schema mart_sales;


-- 1. Order intake by month, division, material group (brief line 35: Sales)
--    active lines only (a rejected line is not an order); the credit memo request counts negative
create view mart_sales.order_intake as
select
    d.year_month,
    f.division,
    m.material_group,
    f.currency,
    count(*) as order_lines,
    sum(f.line_value) as order_intake_value
from semantic.fact_order_line f
join semantic.dim_date d on d.date_key = f.order_creation_date
join semantic.dim_material m on m.material_number = f.material_number
where f.is_rejected = false
group by d.year_month, f.division, m.material_group, f.currency
order by d.year_month, f.division, m.material_group, f.currency;


-- 2. Net revenue by billing month, division and material group
--    (brief line 11: two divisions; schema line 214: revenue date = fkdat)
create view mart_sales.net_revenue_by_division as
select
    d.year_month,
    f.division,
    m.material_group,
    f.document_currency,
    sum(f.item_net_value) as net_revenue
from semantic.fact_billing_line f
join semantic.dim_date d on d.date_key = f.billing_date
join semantic.dim_material m on m.material_number = f.material_number
group by d.year_month, f.division, m.material_group, f.document_currency
order by d.year_month, f.division, m.material_group, f.document_currency;


-- 3. Rejected order value (scenario 3: line cancelled, reason '01')
create view mart_sales.rejected_order_value as
select
    f.currency,
    f.rejection_reason,
    r.description,
    count(*) as rejected_lines,
    sum(f.line_value) as rejected_value
from semantic.fact_order_line f
left join semantic.dim_rejection_reason r on r.rejection_reason_code = f.rejection_reason
where f.is_rejected
group by f.currency, f.rejection_reason, r.description
order by f.currency, f.rejection_reason;


-- 4. Credit memos / returns (scenario 6: 20 units returned, -500 EUR)
--    one row per credit memo billing line (G2), whatever the order type (KR, or RE = returns, schema line 140),
--    with the invoice it reverses (vbrp.vgbel on a G2 line, schema lines 60-63)
create view mart_sales.credit_memos as
select
    f.billing_document_number,
    f.billing_item_number,
    f.billing_date,
    f.payer_customer,
    f.context_dependent_reference as reversed_invoice,   -- G2 only, so vgbel is always an invoice here
    f.material_number,
    f.document_currency,
    f.unit_of_measure,
    f.billed_quantity as returned_quantity,
    f.item_net_value as credited_value
from semantic.fact_billing_line f
where f.billing_type = 'G2'
order by f.billing_document_number, f.billing_item_number;
