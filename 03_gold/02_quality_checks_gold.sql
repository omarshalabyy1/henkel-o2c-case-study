/*
===============================================================================
Quality Checks - Gold
===============================================================================
Script Purpose:
    Every check returns the bad rows.
    - One row per key in the main gold tables (a join must not multiply rows)
    - Every billing document has a receivable item (schema line 65)
    - Money per currency in gold = the raw bronze tables (nothing dropped or doubled)

Expectation:
    No results. run_sql.py runs each check and stops if any returns rows.
===============================================================================
*/

-- =============================================================================
-- One row per key
-- =============================================================================

-- order_lines (key: sales_order_number, item_number)
select sales_order_number, item_number, count(*)
from gold.order_lines
group by sales_order_number, item_number
having count(*) > 1;

-- receivables (key: billing_document_number)
select billing_document_number, count(*)
from gold.receivables
group by billing_document_number
having count(*) > 1;

-- billing_lines (key: billing_document_number, billing_item_number)
select billing_document_number, billing_item_number, count(*)
from gold.billing_lines
group by billing_document_number, billing_item_number
having count(*) > 1;

-- a billing document with no receivable item (schema line 65: AR tracks every invoice)
select billing_document_number
from gold.receivables
where not has_ar_item;

-- customers (key: customer_number)
select customer_number, count(*)
from gold.customers
group by customer_number
having count(*) > 1;

-- materials (key: material_number)
select material_number, count(*)
from gold.materials
group by material_number
having count(*) > 1;


-- =============================================================================
-- Money: gold = raw, per currency (a row loaded twice counts once, as in silver)
-- =============================================================================

-- billed value: gold rows that differ from the raw billing lines
-- (a currency with orders but nothing billed yet sums to 0 in gold and has no raw lines: skip it)
select currency, sum(billed_net_value)
from gold.order_lines
group by currency
having sum(billed_net_value) <> 0
except
select k.waerk, sum(p.netwr)
from (select distinct * from src_vbrp) p
join (select distinct * from src_vbrk) k on k.vbeln = p.vbeln
group by k.waerk;

-- billed value: raw currencies missing or different in gold
select k.waerk, sum(p.netwr)
from (select distinct * from src_vbrp) p
join (select distinct * from src_vbrk) k on k.vbeln = p.vbeln
group by k.waerk
except
select currency, sum(billed_net_value)
from gold.order_lines
group by currency
having sum(billed_net_value) <> 0;

-- billing lines: gold rows that differ from the raw billing lines
select document_currency, sum(item_net_value)
from gold.billing_lines
group by document_currency
except
select k.waerk, sum(p.netwr)
from (select distinct * from src_vbrp) p
join (select distinct * from src_vbrk) k on k.vbeln = p.vbeln
group by k.waerk;

-- billing lines: raw currencies missing or different in gold
select k.waerk, sum(p.netwr)
from (select distinct * from src_vbrp) p
join (select distinct * from src_vbrk) k on k.vbeln = p.vbeln
group by k.waerk
except
select document_currency, sum(item_net_value)
from gold.billing_lines
group by document_currency;

-- open receivables: gold rows that differ from the raw open items
-- (an item also in bsad is cleared, not open)
select document_currency, sum(amount_in_document_currency)
from gold.receivables
where is_open
group by document_currency
except
select i.waers, sum(i.wrbtr)
from (select distinct * from src_bsid) i
where not exists (select 1 from src_bsad c
                  where c.bukrs = i.bukrs and c.belnr = i.belnr and c.gjahr = i.gjahr and c.buzei = i.buzei)
group by i.waers;

-- open receivables: raw currencies missing or different in gold
select i.waers, sum(i.wrbtr)
from (select distinct * from src_bsid) i
where not exists (select 1 from src_bsad c
                  where c.bukrs = i.bukrs and c.belnr = i.belnr and c.gjahr = i.gjahr and c.buzei = i.buzei)
group by i.waers
except
select document_currency, sum(amount_in_document_currency)
from gold.receivables
where is_open
group by document_currency;
