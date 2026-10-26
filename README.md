# FlorAI Flower Import & Wholesale Database

## Files
- `florai.db`: SQLite database with schema, reporting views, reference data, and synthetic example transactions.
- `schema.sql`: Full schema and indexes for SQLite.
- `starter_queries.sql`: Example queries to explore the data.
- `README.md`: Setup notes, table groups, limitations, and next steps.

## Open it
The included `.db` file is a SQLite database. You can open it with:
- DB Browser for SQLite: https://sqlitebrowser.org/
- DBeaver: https://dbeaver.io/
- Python's built-in `sqlite3` module.

Example:
```python
import sqlite3
con = sqlite3.connect("florai.db")
con.execute("PRAGMA foreign_keys = ON")
print(con.execute("SELECT * FROM v_inventory_by_lot LIMIT 10").fetchall())
con.close()
```

## Included business modules
- Master data: countries, currencies, products, packaging conversions, suppliers, customers, warehouses.
- Procurement/imports: purchase orders, shipments, shipment items, freight/import charges, receipts.
- Inventory: lots, movement ledger, reservations, quality inspections, waste, transfers.
- Sales: sales orders, fulfillment, invoices, returns, credits, price lists.
- Finance: supplier/customer invoices and payment allocations, chart of accounts, journals, bank records.
- Logistics and controls: carriers, tracking events, delivery records, quality claims, audit log, application users.
- Reporting views: inventory by lot, A/R aging, A/P aging, sales by product, monthly sales, supplier spend, waste, journal balance.

## Important limitations
This is a portfolio/demo starter database, not production accounting software. It uses SQLite so it is easy to download and begin exploring without installing a database server. PostgreSQL is recommended before building a multi-user production application.
- All sample business transactions, suppliers, customers, and prices are synthetic and fictional.
- Some sample unit conversions are illustrative defaults only; verify each product's real packaging configuration.
- Financial records in different currencies must be reported by currency unless converted using a documented transaction-date exchange rate. Do not sum different currencies directly.
- `inventory_lots.initial_quantity_stems` represents accepted stock at receipt. The movement ledger is intended to track subsequent changes. Ensure receipt/waste postings are not double-counted when you build posting workflows.
- The schema defines operational accounting tables but does not automatically post every transaction to balanced journal entries. Implement and test posting logic before relying on financial statements.
- Cross-row rules (payment allocations not exceeding payment/invoice balances, journal entries balancing, and stock availability) require transactional application logic or triggers; basic CHECK constraints cannot enforce all of them.
- Review tax, customs, record retention, and accounting treatment with qualified professionals before real business use.

## Suggested first exercises
1. Query current inventory:
   `SELECT * FROM v_inventory_by_lot;`
2. Review unpaid customer invoices:
   `SELECT * FROM v_accounts_receivable_aging WHERE outstanding_amount > 0;`
3. Review supplier bills:
   `SELECT * FROM v_accounts_payable_aging WHERE outstanding_amount > 0;`
4. Compare sales by product:
   `SELECT * FROM v_sales_by_product ORDER BY sales_revenue DESC;`
5. Explore waste:
   `SELECT * FROM v_waste_by_product ORDER BY estimated_waste_cost_usd DESC;`

## Next recommended step
Build a Python/Streamlit app around the database. Start with a read-only dashboard, then implement validated workflows for receiving stock, fulfilling orders, posting invoices, and allocating payments.
