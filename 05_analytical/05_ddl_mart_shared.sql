/*
===============================================================================
DDL Script: Create the shared data mart
===============================================================================
Script Purpose:
    Creates the 'mart_shared' schema: small lists every department uses.
    currency: one row per currency found in the facts (no hard-coded list).
    Power BI links it 1 -> N to every mart view that holds money, so one
    slicer filters them all and EUR and USD are never added together.

Usage:
    python run_sql.py   (runs after the department marts, before their checks)
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
