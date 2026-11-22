/*
===============================================================================
Shared mart: the currency list
===============================================================================
One row per currency found in the facts. Power BI links it to every view
that holds money, so one slicer filters them all and EUR and USD never add up.

Run: python run_sql.py
===============================================================================
*/

drop schema if exists mart_shared cascade;
create schema mart_shared;


-- currency: every currency used by the facts (today EUR, USD)
create view mart_shared.currency as
select currency from semantic.fact_order_line
union
select document_currency from semantic.fact_receivable
union
select document_currency from semantic.fact_billing_line
order by currency;
