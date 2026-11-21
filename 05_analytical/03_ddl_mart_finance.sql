/*
===============================================================================
DDL Script: Create the Finance data mart
===============================================================================
Script Purpose:
    Creates the 'mart_finance' schema: the KPIs the Finance team reads directly
    (brief line 35: Finance, Sales and Operations; line 115: work with it directly).
    What is still to invoice, revenue by billing month, and what customers still owe.
    Every view reads only the semantic star schema, so all marts share one
    definition of customers, materials, dates, orders and revenue.
    Money is always per currency (EUR and USD are never added).
    "Today" = 2026-05-04, the extract date stated in 02_sample_data.sql.

Usage:
    python run_sql.py   (runs after the semantic layer and its checks)
===============================================================================
*/

drop schema if exists mart_finance cascade;
create schema mart_finance;


-- 1. Billing backlog: delivered, not billed (scenario 7, data line 280)
create view mart_finance.billing_backlog as
select
    f.sales_order_number,
    f.item_number,
    f.sold_to_customer,
    f.currency,
    f.last_goods_issue_date,
    f.delivered_not_billed_value
from semantic.fact_order_line f
where f.delivered_not_billed_value <> 0
order by f.sales_order_number, f.item_number;


-- 2. Net revenue by billing month (schema line 214: revenue date = fkdat)
create view mart_finance.net_revenue_by_month as
select
    d.year_month,
    r.document_currency,
    count(*) filter (where r.billing_type = 'F2') as invoices,
    sum(r.net_billing_value) filter (where r.billing_type = 'F2') as invoiced_value,
    sum(r.net_billing_value) filter (where r.billing_type in ('G2', 'S1')) as credited_value,
    sum(r.net_billing_value) as net_revenue
from semantic.fact_receivable r
join semantic.dim_date d on d.date_key = r.billing_date
group by d.year_month, r.document_currency
order by d.year_month, r.document_currency;


-- 3. Open receivables: one row per open invoice, who owes it, overdue or not yet due
--    (scenarios 2, 7, 8; brief line 35: Finance asks who still owes what)
create view mart_finance.open_receivables as
select
    r.billing_document_number,
    r.payer_customer,
    c.customer_name,
    r.document_currency,
    r.amount_in_document_currency,
    r.net_due_date,
    r.days_overdue,                   -- negative = not due yet
    r.days_overdue > 0 as is_overdue
from semantic.fact_receivable r
join semantic.dim_customer c on c.customer_number = r.payer_customer
where r.is_open
order by r.billing_document_number;


-- 4. Days to pay: billing date to clearing date, invoices only (scenario 1: "paid EARLY";
--    the credit memo is cleared by offset, not paid); one row per currency
create view mart_finance.days_to_pay as
select
    r.document_currency,
    count(*) as paid_invoices,
    round(avg(r.days_to_pay), 2) as avg_days_to_pay,
    count(*) filter (where r.clearing_date <= r.net_due_date) as paid_by_due_date
from semantic.fact_receivable r
where r.billing_type = 'F2' and r.clearing_date is not null
group by r.document_currency
order by r.document_currency;
