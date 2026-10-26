-- FlorAI starter queries (SQLite)

-- 1. Inventory by lot
SELECT * FROM v_inventory_by_lot ORDER BY received_date DESC;

-- 2. Inventory with freshness approaching (next 3 days)
SELECT lot_code, product_name, origin_country, warehouse_name,
       calculated_on_hand_stems, estimated_sell_by_date
FROM v_inventory_by_lot
WHERE calculated_on_hand_stems > 0
  AND estimated_sell_by_date BETWEEN date('now') AND date('now','+3 day')
ORDER BY estimated_sell_by_date;

-- 3. Accounts receivable with open balances
SELECT * FROM v_accounts_receivable_aging
WHERE outstanding_amount > 0
ORDER BY due_date;

-- 4. Accounts payable with open balances
SELECT * FROM v_accounts_payable_aging
WHERE outstanding_amount > 0
ORDER BY due_date;

-- 5. Sales by product
SELECT * FROM v_sales_by_product ORDER BY sales_revenue DESC;

-- 6. Waste by product
SELECT * FROM v_waste_by_product ORDER BY estimated_waste_cost_usd DESC;

-- 7. Monthly sales
SELECT * FROM v_monthly_sales ORDER BY sales_month;

-- 8. Purchasing by supplier
SELECT s.supplier_name, s.country_code, po.currency_code,
       COUNT(DISTINCT po.purchase_order_id) AS purchase_orders,
       SUM(poi.quantity_ordered * poi.unit_price) AS ordered_value
FROM suppliers s
JOIN purchase_orders po ON po.supplier_id = s.supplier_id
JOIN purchase_order_items poi ON poi.purchase_order_id = po.purchase_order_id
GROUP BY s.supplier_id, s.supplier_name, s.country_code, po.currency_code
ORDER BY ordered_value DESC;

-- 9. Shipment discrepancies: compare ordered quantity with shipped quantity
SELECT po.po_number, p.product_name,
       poi.quantity_ordered, poi.uom_code,
       si.quantity_shipped, si.uom_code AS shipped_uom,
       sh.shipment_reference, sh.status
FROM purchase_order_items poi
JOIN purchase_orders po ON po.purchase_order_id = poi.purchase_order_id
JOIN products p ON p.product_id = poi.product_id
LEFT JOIN shipment_items si ON si.po_item_id = poi.po_item_id
LEFT JOIN shipments sh ON sh.shipment_id = si.shipment_id
ORDER BY po.order_date DESC;

-- 10. Journal entries that do not balance (should be none among posted entries once posting logic exists)
SELECT * FROM v_journal_entry_balance
WHERE status = 'posted' AND ABS(difference) > 0.005;

-- 11. Customers by invoiced revenue
SELECT c.customer_name, SUM(i.total_amount) AS invoiced_revenue
FROM customers c JOIN sales_invoices i ON i.customer_id = c.customer_id
WHERE i.status NOT IN ('draft','void')
GROUP BY c.customer_id, c.customer_name
ORDER BY invoiced_revenue DESC;

-- 12. Lot traceability
SELECT l.lot_code, p.product_name, c.country_name AS growing_origin,
       s.supplier_name, sh.shipment_reference, gr.receipt_number,
       l.received_date, l.estimated_sell_by_date
FROM inventory_lots l
JOIN products p ON p.product_id = l.product_id
JOIN countries c ON c.country_code = l.origin_country_code
LEFT JOIN suppliers s ON s.supplier_id = l.supplier_id
LEFT JOIN shipment_items si ON si.shipment_item_id = l.shipment_item_id
LEFT JOIN shipments sh ON sh.shipment_id = si.shipment_id
LEFT JOIN goods_receipt_items gri ON gri.receipt_item_id = l.receipt_item_id
LEFT JOIN goods_receipts gr ON gr.goods_receipt_id = gri.goods_receipt_id;
