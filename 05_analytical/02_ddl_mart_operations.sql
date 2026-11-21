/*
===============================================================================
DDL Script: Create the Operations data mart
===============================================================================
Script Purpose:
    Creates the 'mart_operations' schema: the KPIs the Operations team reads directly
    (brief line 35: Finance, Sales and Operations; line 115: work with it directly).
    What is still to ship, and whether shipments leave on time.
    Every view reads only the semantic star schema, so all marts share one
    definition of customers, materials, dates, orders and revenue.
    Money is always per currency (EUR and USD are never added).
    "Today" = 2026-05-04, the extract date stated in 02_sample_data.sql.

Usage:
    python run_sql.py   (runs after the semantic layer and its checks)
===============================================================================
*/

drop schema if exists mart_operations cascade;
create schema mart_operations;


-- 1. Open order backlog: ordered, not shipped (scenario 4, data line 195)
create view mart_operations.open_order_backlog as
select
    f.sales_order_number,
    f.sold_to_customer,
    f.currency,
    f.customer_requested_delivery_date,
    date '2026-05-04' - f.customer_requested_delivery_date as days_past_requested_date,
    sum(f.open_to_ship_value) as open_to_ship_value
from semantic.fact_order_line f
where f.open_to_ship_value <> 0
group by f.sales_order_number, f.sold_to_customer, f.currency, f.customer_requested_delivery_date
order by f.sales_order_number;


-- 2. On-time delivery: line fully shipped on or before the requested delivery date
--    (scenarios 1-3, 5, 7, 8: "ON TIME" / "LATE"); is_on_time is empty until fully shipped
--    one row per currency, so the currency slicer filters it like the money views
create view mart_operations.on_time_delivery as
select
    f.currency,
    count(*) filter (where f.is_on_time is not null) as fully_shipped_lines,
    count(*) filter (where f.is_on_time) as on_time_lines,
    round(count(*) filter (where f.is_on_time) / count(*) filter (where f.is_on_time is not null), 3) as on_time_rate,
    max(f.days_late) as worst_days_late,
    count(*) filter (where f.is_past_due_unshipped) as past_due_unshipped_lines
from semantic.fact_order_line f
group by f.currency
order by f.currency;


-- 3. On-time delivery per order line: the rows behind on_time_delivery, for drill-through
--    (one row per order line that has shipped or is past due; same columns as the fact)
create view mart_operations.on_time_delivery_by_line as
select
    f.sales_order_number,
    f.item_number,
    f.sold_to_customer,
    f.currency,
    f.customer_requested_delivery_date,
    f.last_goods_issue_date,          -- empty if not shipped
    f.days_late,                      -- empty if not shipped
    f.is_on_time,                     -- empty until fully shipped
    f.is_past_due_unshipped
from semantic.fact_order_line f
where f.last_goods_issue_date is not null or f.is_past_due_unshipped
order by f.sales_order_number, f.item_number;
