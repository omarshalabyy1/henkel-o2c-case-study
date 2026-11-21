/*
===============================================================================
Quality Checks - Silver
===============================================================================
Script Purpose:
    Duplicate keys, NULL keys and broken links are already refused by the
    PRIMARY KEY / FOREIGN KEY constraints in 01_ddl_silver.sql.
    These checks cover Henkel's rules that a constraint cannot express.
    Every check returns the bad rows.

Expectation:
    No results. run_sql.py runs each check and stops if any returns rows.
===============================================================================
*/

-- a rejected order line was shipped (schema line 165: must NOT be shipped)
select l.sales_order_number, l.item_number
from silver.order_lines l
where l.is_rejected
  and exists (select 1 from silver.delivery_lines d
              where d.originating_sales_order = l.sales_order_number
                and d.originating_sales_order_item = l.item_number);

-- a rejected order line was billed (schema line 165: must NOT be billed)
select l.sales_order_number, l.item_number
from silver.order_lines l
where l.is_rejected
  and exists (select 1 from silver.billing_lines b
              where b.originating_sales_order = l.sales_order_number
                and b.originating_sales_order_item = l.item_number);

-- a credit memo or cancellation header value is not negative (schema line 212: negative)
select billing_document_number, billing_type, net_billing_value
from silver.billing_docs
where billing_type in ('G2', 'S1') and net_billing_value >= 0;

-- a credit memo or cancellation line value is not negative (schema line 227: negative)
select b.billing_document_number, b.billing_item_number, b.item_net_value
from silver.billing_lines b
join silver.billing_docs d on d.billing_document_number = b.billing_document_number
where d.billing_type in ('G2', 'S1') and b.item_net_value >= 0;

-- order header net value differs from its active lines (schema line 145, data line 160)
select o.sales_order_number, o.net_order_value, sum(l.line_value) as active_lines_value
from silver.orders o
join silver.order_lines l on l.sales_order_number = o.sales_order_number
where l.is_rejected = false
group by o.sales_order_number, o.net_order_value
having o.net_order_value <> sum(l.line_value);

-- order line currency differs from its order currency (schema line 160)
select l.sales_order_number, l.item_number, l.currency, o.document_currency
from silver.order_lines l
join silver.orders o on o.sales_order_number = l.sales_order_number
where l.currency <> o.document_currency;

-- unknown or missing order type or item category (schema lines 140, 162)
select sales_order_number, order_type
from silver.orders
where order_type is null or order_type not in ('TA', 'KR', 'RE');

select sales_order_number, item_number, item_category
from silver.order_lines
where item_category is null or item_category not in ('TAN', 'KRN', 'TANN');

-- unknown or missing billing type (schema line 209)
select billing_document_number, billing_type
from silver.billing_docs
where billing_type is null or billing_type not in ('F2', 'G2', 'S1');

-- unknown or missing material type (schema line 114)
select material_number, material_type
from silver.materials
where material_type is null or material_type not in ('FERT', 'HALB', 'ROH');

-- a receivable is in BOTH open and cleared items (schema line 248: it moved, and the
-- extract cannot tell which list is current; like a conflicting duplicate, stop and report)
select o.company_code, o.fi_document_number, o.fiscal_year, o.line_item_number
from silver.open_items o
join silver.cleared_items c
  on c.company_code = o.company_code
 and c.fi_document_number = o.fi_document_number
 and c.fiscal_year = o.fiscal_year
 and c.line_item_number = o.line_item_number;

-- a billing line's reference is not what its billing type says (schema lines 60-63, 230-233):
-- invoice (F2) -> a delivery, credit memo (G2) -> a billing document
select b.billing_document_number, b.billing_item_number, d.billing_type, b.context_dependent_reference
from silver.billing_lines b
join silver.billing_docs d on d.billing_document_number = b.billing_document_number
where (d.billing_type = 'F2'
       and not exists (select 1 from silver.deliveries x where x.delivery_number = b.context_dependent_reference))
   or (d.billing_type = 'G2'
       and not exists (select 1 from silver.billing_docs x where x.billing_document_number = b.context_dependent_reference));

-- a delivery line's unit differs from its order line's unit (schema lines 158, 193)
select dl.delivery_number, dl.delivery_item_number, dl.unit_of_measure, l.unit_of_measure
from silver.delivery_lines dl
join silver.order_lines l
  on l.sales_order_number = dl.originating_sales_order
 and l.item_number = dl.originating_sales_order_item
where dl.unit_of_measure <> l.unit_of_measure;

-- a standard order (TA) has no requested delivery date (schema line 147: needed for on time)
select sales_order_number
from silver.orders
where order_type = 'TA' and customer_requested_delivery_date is null;

-- an invoice (F2) line's delivery belongs to another order (schema lines 60-63: vgbel = the delivery)
select b.billing_document_number, b.billing_item_number, b.context_dependent_reference, b.originating_sales_order
from silver.billing_lines b
join silver.billing_docs d on d.billing_document_number = b.billing_document_number
where d.billing_type = 'F2'
  and not exists (select 1 from silver.delivery_lines x
                  where x.delivery_number = b.context_dependent_reference
                    and x.originating_sales_order = b.originating_sales_order);

-- an order line quantity is not in the material's base unit (schema line 157: "in base UOM")
select l.sales_order_number, l.item_number, l.unit_of_measure, m.base_unit_of_measure
from silver.order_lines l
join silver.materials m on m.material_number = l.material_number
where l.unit_of_measure <> m.base_unit_of_measure;

-- a material has no English description (schema lines 21, 120: makt holds one per language)
select m.material_number
from silver.materials m
where not exists (select 1 from silver.material_names n where n.material_number = m.material_number);
