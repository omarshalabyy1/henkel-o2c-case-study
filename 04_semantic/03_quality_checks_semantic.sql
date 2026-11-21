/*
===============================================================================
Quality Checks - Semantic
===============================================================================
Script Purpose:
    Keys and links are already enforced by the PRIMARY KEY / FOREIGN KEY
    constraints in 01_ddl_semantic.sql (a fact row pointing to a missing
    customer, material or date stops the load).
    These checks cover what a constraint cannot express.
    Every check returns the bad rows.

Expectation:
    No results. run_sql.py runs each check and stops if any returns rows.
===============================================================================
*/

-- dim_date has a gap (it must hold every day from its first to its last date)
select min(date_key), max(date_key), count(*)
from semantic.dim_date
having count(*) <> max(date_key) - min(date_key) + 1;

-- dim_date does not cover "today" (2026-05-04), the as-of date of the extract
select 'today missing from dim_date'
where not exists (select 1 from semantic.dim_date where date_key = date '2026-05-04');

-- the star schema lost or added rows compared with gold
select 'fact_order_line' as table_name
where (select count(*) from semantic.fact_order_line) <> (select count(*) from gold.order_lines)
union all
select 'fact_receivable'
where (select count(*) from semantic.fact_receivable) <> (select count(*) from gold.receivables)
union all
select 'fact_billing_line'
where (select count(*) from semantic.fact_billing_line) <> (select count(*) from gold.billing_lines);
