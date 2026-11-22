/*
===============================================================================
Load the star schema from gold
===============================================================================
Dimensions first, then facts. dim_date has one row per day from the
earliest fact date to the latest (or 2026-05-04, if later).

Run: python run_sql.py
===============================================================================
*/

-- every date used by the facts, plus today (2026-05-04, the date the KPIs are measured on)
create temp table all_dates as
select order_creation_date as d from gold.order_lines
union all select customer_requested_delivery_date from gold.order_lines
union all select last_goods_issue_date from gold.order_lines
union all select billing_date from gold.receivables
union all select net_due_date from gold.receivables
union all select clearing_date from gold.receivables
union all select date '2026-05-04';

-- dim_date: one row per day from min to max
insert into semantic.dim_date by name
select
    day::date as date_key,
    year(day) as year,
    quarter(day) as quarter,
    month(day) as month,
    monthname(day) as month_name,
    strftime(day, '%Y-%m') as year_month,
    day(day) as day_of_month,
    dayname(day) as weekday_name
from generate_series(
    (select min(d) from all_dates),
    (select max(d) from all_dates),
    interval 1 day
) as t(day);

drop table all_dates;

insert into semantic.dim_customer by name
select * from gold.customers;

insert into semantic.dim_material by name
select * from gold.materials;

insert into semantic.dim_sales_organization by name
select * from gold.sales_organizations;

insert into semantic.dim_distribution_channel by name
select * from gold.distribution_channels;

insert into semantic.dim_plant by name
select * from gold.plants;

insert into semantic.dim_rejection_reason by name
select * from gold.rejection_reasons;

insert into semantic.fact_order_line by name
select * from gold.order_lines;

insert into semantic.fact_receivable by name
select * from gold.receivables;

insert into semantic.fact_billing_line by name
select * from gold.billing_lines;
