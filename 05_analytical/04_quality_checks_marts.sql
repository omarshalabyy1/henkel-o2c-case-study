/*
===============================================================================
Quality Checks - Data marts
===============================================================================
Script Purpose:
    Cross-checks KPIs across marts: billing headers must equal billing lines
    per billing month and currency, and order intake must equal the order
    headers (these checks also read silver). Every check returns the bad rows.

Expectation:
    No results. run_sql.py runs each check and stops if any returns rows.
===============================================================================
*/

-- net revenue per billing month and currency: Finance (billing headers) = Sales (billing lines)
select year_month, document_currency, net_revenue
from mart_finance.net_revenue_by_month
except
select year_month, document_currency, sum(net_revenue)
from mart_sales.net_revenue_by_division
group by year_month, document_currency;

-- the other way: a month / currency in Sales missing or different in Finance
select year_month, document_currency, sum(net_revenue)
from mart_sales.net_revenue_by_division
group by year_month, document_currency
except
select year_month, document_currency, net_revenue
from mart_finance.net_revenue_by_month;

-- order intake per currency = the order headers' net value (schema line 145: active items only)
select currency, sum(order_intake_value)
from mart_sales.order_intake
group by currency
except
select document_currency, sum(net_order_value)
from silver.orders
group by document_currency;

-- on-time per line adds up to the on-time summary, per currency (lines, on time, worst delay, past due)
select
    currency,
    count(*) filter (where is_on_time is not null),
    count(*) filter (where is_on_time),
    greatest(max(days_late) filter (where is_on_time is not null), 0),
    count(*) filter (where is_past_due_unshipped)
from mart_operations.on_time_delivery_by_line
group by currency
except
select currency, fully_shipped_lines, on_time_lines, worst_days_late, past_due_unshipped_lines
from mart_operations.on_time_delivery;

-- on-time summary per currency adds back up to all order lines
select sum(fully_shipped_lines), sum(on_time_lines), max(worst_days_late), sum(past_due_unshipped_lines)
from mart_operations.on_time_delivery
except
select
    count(*) filter (where is_on_time is not null),
    count(*) filter (where is_on_time),
    greatest(max(days_late) filter (where is_on_time is not null), 0),
    count(*) filter (where is_past_due_unshipped)
from semantic.fact_order_line;

-- days to pay per currency adds back up to all paid invoices
select sum(paid_invoices), sum(paid_by_due_date)
from mart_finance.days_to_pay
except
select count(*), count(*) filter (where clearing_date <= net_due_date)
from semantic.fact_receivable
where billing_type = 'F2' and clearing_date is not null;

-- every currency in a money view is in mart_shared.currency (Power BI's currency slicer)
select currency from mart_sales.order_intake
union select document_currency from mart_sales.net_revenue_by_division
union select currency from mart_sales.rejected_order_value
union select document_currency from mart_sales.credit_memos
union select currency from mart_operations.open_order_backlog
union select currency from mart_operations.on_time_delivery_by_line
union select currency from mart_operations.on_time_delivery
union select currency from mart_finance.billing_backlog
union select document_currency from mart_finance.net_revenue_by_month
union select document_currency from mart_finance.open_receivables
union select document_currency from mart_finance.days_to_pay
except
select currency from mart_shared.currency;
