
PRAGMA foreign_keys = ON;

CREATE TABLE countries (
    country_code TEXT PRIMARY KEY,
    country_name TEXT NOT NULL UNIQUE
);

CREATE TABLE currencies (
    currency_code TEXT PRIMARY KEY,
    currency_name TEXT NOT NULL
);

CREATE TABLE exchange_rates (
    exchange_rate_id INTEGER PRIMARY KEY,
    currency_code TEXT NOT NULL REFERENCES currencies(currency_code),
    rate_date TEXT NOT NULL,
    usd_rate NUMERIC NOT NULL CHECK (usd_rate > 0),
    UNIQUE(currency_code, rate_date)
);

CREATE TABLE product_categories (
    category_id INTEGER PRIMARY KEY,
    category_name TEXT NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE products (
    product_id INTEGER PRIMARY KEY,
    sku TEXT NOT NULL UNIQUE,
    product_name TEXT NOT NULL,
    category_id INTEGER NOT NULL REFERENCES product_categories(category_id),
    variety TEXT,
    color TEXT,
    grade TEXT,
    stem_length_cm INTEGER CHECK (stem_length_cm IS NULL OR stem_length_cm > 0),
    active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE units_of_measure (
    uom_code TEXT PRIMARY KEY,
    unit_name TEXT NOT NULL UNIQUE,
    is_count_unit INTEGER NOT NULL DEFAULT 0 CHECK (is_count_unit IN (0,1))
);

-- Conversion is product/packaging-specific. One unit_from equals factor units_to.
CREATE TABLE product_unit_conversions (
    conversion_id INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    unit_from TEXT NOT NULL REFERENCES units_of_measure(uom_code),
    unit_to TEXT NOT NULL REFERENCES units_of_measure(uom_code),
    factor NUMERIC NOT NULL CHECK (factor > 0),
    valid_from TEXT NOT NULL,
    valid_to TEXT,
    CHECK (unit_from <> unit_to),
    CHECK (valid_to IS NULL OR valid_to >= valid_from),
    UNIQUE(product_id, unit_from, unit_to, valid_from)
);

CREATE TABLE suppliers (
    supplier_id INTEGER PRIMARY KEY,
    supplier_code TEXT NOT NULL UNIQUE,
    supplier_name TEXT NOT NULL,
    supplier_type TEXT NOT NULL CHECK (supplier_type IN ('farm','exporter','broker','freight_provider','other')),
    country_code TEXT NOT NULL REFERENCES countries(country_code),
    city TEXT,
    email TEXT,
    phone TEXT,
    payment_terms_days INTEGER NOT NULL DEFAULT 30 CHECK (payment_terms_days >= 0),
    currency_code TEXT NOT NULL DEFAULT 'USD' REFERENCES currencies(currency_code),
    active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE customers (
    customer_id INTEGER PRIMARY KEY,
    customer_code TEXT NOT NULL UNIQUE,
    customer_name TEXT NOT NULL,
    customer_type TEXT NOT NULL CHECK (customer_type IN ('wholesale_florist','event_planner','retailer','individual','other')),
    country_code TEXT REFERENCES countries(country_code),
    city TEXT,
    state TEXT,
    postal_code TEXT,
    email TEXT,
    phone TEXT,
    credit_limit NUMERIC NOT NULL DEFAULT 0 CHECK (credit_limit >= 0),
    payment_terms_days INTEGER NOT NULL DEFAULT 0 CHECK (payment_terms_days >= 0),
    active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE customer_contacts (
    contact_id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    contact_name TEXT NOT NULL,
    role TEXT,
    email TEXT,
    phone TEXT,
    is_primary INTEGER NOT NULL DEFAULT 0 CHECK (is_primary IN (0,1))
);

CREATE TABLE warehouses (
    warehouse_id INTEGER PRIMARY KEY,
    warehouse_name TEXT NOT NULL UNIQUE,
    address TEXT,
    city TEXT NOT NULL DEFAULT 'New York',
    state TEXT NOT NULL DEFAULT 'NY',
    active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1))
);

CREATE TABLE storage_locations (
    location_id INTEGER PRIMARY KEY,
    warehouse_id INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    location_code TEXT NOT NULL,
    description TEXT,
    temperature_c NUMERIC,
    UNIQUE(warehouse_id, location_code)
);

CREATE TABLE employees (
    employee_id INTEGER PRIMARY KEY,
    employee_name TEXT NOT NULL,
    email TEXT UNIQUE,
    role_name TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1))
);

CREATE TABLE payment_terms (
    payment_terms_id INTEGER PRIMARY KEY,
    terms_name TEXT NOT NULL UNIQUE,
    days_due INTEGER NOT NULL CHECK (days_due >= 0),
    description TEXT
);

CREATE TABLE carriers (
    carrier_id INTEGER PRIMARY KEY,
    carrier_name TEXT NOT NULL UNIQUE,
    carrier_type TEXT NOT NULL CHECK (carrier_type IN ('air','truck','courier','other')),
    contact_email TEXT
);

CREATE TABLE purchase_orders (
    purchase_order_id INTEGER PRIMARY KEY,
    po_number TEXT NOT NULL UNIQUE,
    supplier_id INTEGER NOT NULL REFERENCES suppliers(supplier_id),
    order_date TEXT NOT NULL,
    expected_delivery_date TEXT,
    currency_code TEXT NOT NULL REFERENCES currencies(currency_code),
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','approved','partially_received','received','cancelled','closed')),
    payment_terms_id INTEGER REFERENCES payment_terms(payment_terms_id),
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (expected_delivery_date IS NULL OR expected_delivery_date >= order_date)
);

CREATE TABLE purchase_order_items (
    po_item_id INTEGER PRIMARY KEY,
    purchase_order_id INTEGER NOT NULL REFERENCES purchase_orders(purchase_order_id),
    line_number INTEGER NOT NULL,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    quantity_ordered NUMERIC NOT NULL CHECK (quantity_ordered > 0),
    uom_code TEXT NOT NULL REFERENCES units_of_measure(uom_code),
    unit_price NUMERIC NOT NULL CHECK (unit_price >= 0),
    grade TEXT,
    UNIQUE(purchase_order_id, line_number)
);

CREATE TABLE shipments (
    shipment_id INTEGER PRIMARY KEY,
    shipment_reference TEXT NOT NULL UNIQUE,
    exporter_supplier_id INTEGER REFERENCES suppliers(supplier_id),
    carrier_id INTEGER REFERENCES carriers(carrier_id),
    origin_country_code TEXT NOT NULL REFERENCES countries(country_code),
    origin_airport_or_port TEXT,
    destination_airport_or_port TEXT,
    airway_bill_or_tracking TEXT,
    departure_date TEXT,
    expected_arrival_date TEXT,
    actual_arrival_date TEXT,
    status TEXT NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_transit','arrived','received','delayed','cancelled')),
    temperature_notes TEXT,
    documents_notes TEXT,
    CHECK (actual_arrival_date IS NULL OR departure_date IS NULL OR actual_arrival_date >= departure_date)
);

CREATE TABLE shipment_items (
    shipment_item_id INTEGER PRIMARY KEY,
    shipment_id INTEGER NOT NULL REFERENCES shipments(shipment_id),
    po_item_id INTEGER REFERENCES purchase_order_items(po_item_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    grower_supplier_id INTEGER REFERENCES suppliers(supplier_id),
    origin_country_code TEXT NOT NULL REFERENCES countries(country_code),
    quantity_shipped NUMERIC NOT NULL CHECK (quantity_shipped > 0),
    uom_code TEXT NOT NULL REFERENCES units_of_measure(uom_code),
    purchase_unit_cost NUMERIC NOT NULL CHECK (purchase_unit_cost >= 0),
    currency_code TEXT NOT NULL REFERENCES currencies(currency_code),
    lot_code TEXT,
    UNIQUE(shipment_id, product_id, lot_code)
);

CREATE TABLE freight_charges (
    freight_charge_id INTEGER PRIMARY KEY,
    shipment_id INTEGER NOT NULL REFERENCES shipments(shipment_id),
    supplier_id INTEGER REFERENCES suppliers(supplier_id),
    charge_type TEXT NOT NULL CHECK (charge_type IN ('freight','insurance','handling','brokerage','customs_duty','inspection','other')),
    description TEXT,
    amount NUMERIC NOT NULL CHECK (amount >= 0),
    currency_code TEXT NOT NULL REFERENCES currencies(currency_code),
    allocation_basis TEXT NOT NULL DEFAULT 'value' CHECK (allocation_basis IN ('value','quantity','weight','volume','manual')),
    charge_date TEXT
);

CREATE TABLE goods_receipts (
    goods_receipt_id INTEGER PRIMARY KEY,
    receipt_number TEXT NOT NULL UNIQUE,
    shipment_id INTEGER NOT NULL REFERENCES shipments(shipment_id),
    warehouse_id INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    received_at TEXT NOT NULL,
    received_by INTEGER REFERENCES employees(employee_id),
    notes TEXT
);

CREATE TABLE goods_receipt_items (
    receipt_item_id INTEGER PRIMARY KEY,
    goods_receipt_id INTEGER NOT NULL REFERENCES goods_receipts(goods_receipt_id),
    shipment_item_id INTEGER NOT NULL REFERENCES shipment_items(shipment_item_id),
    location_id INTEGER REFERENCES storage_locations(location_id),
    quantity_received NUMERIC NOT NULL CHECK (quantity_received >= 0),
    quantity_accepted NUMERIC NOT NULL CHECK (quantity_accepted >= 0),
    quantity_rejected NUMERIC NOT NULL DEFAULT 0 CHECK (quantity_rejected >= 0),
    uom_code TEXT NOT NULL REFERENCES units_of_measure(uom_code),
    CHECK (quantity_accepted + quantity_rejected <= quantity_received)
);

CREATE TABLE inventory_lots (
    lot_id INTEGER PRIMARY KEY,
    lot_code TEXT NOT NULL UNIQUE,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    shipment_item_id INTEGER REFERENCES shipment_items(shipment_item_id),
    receipt_item_id INTEGER REFERENCES goods_receipt_items(receipt_item_id),
    supplier_id INTEGER REFERENCES suppliers(supplier_id),
    origin_country_code TEXT NOT NULL REFERENCES countries(country_code),
    warehouse_id INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    location_id INTEGER REFERENCES storage_locations(location_id),
    received_date TEXT NOT NULL,
    estimated_sell_by_date TEXT,
    initial_quantity_stems NUMERIC NOT NULL CHECK (initial_quantity_stems >= 0),
    unit_cost_usd NUMERIC NOT NULL CHECK (unit_cost_usd >= 0),
    quality_status TEXT NOT NULL DEFAULT 'accepted' CHECK (quality_status IN ('pending','accepted','watch','rejected','disposed')),
    notes TEXT,
    CHECK (estimated_sell_by_date IS NULL OR estimated_sell_by_date >= received_date)
);

CREATE TABLE inventory_transactions (
    inventory_transaction_id INTEGER PRIMARY KEY,
    transaction_ref TEXT NOT NULL UNIQUE,
    lot_id INTEGER NOT NULL REFERENCES inventory_lots(lot_id),
    transaction_date TEXT NOT NULL,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('receipt','sale','reservation','release_reservation','transfer_in','transfer_out','damage','waste','adjustment_in','adjustment_out','return')),
    quantity_stems NUMERIC NOT NULL CHECK (quantity_stems > 0),
    from_warehouse_id INTEGER REFERENCES warehouses(warehouse_id),
    to_warehouse_id INTEGER REFERENCES warehouses(warehouse_id),
    reference_type TEXT,
    reference_id INTEGER,
    reason TEXT,
    created_by INTEGER REFERENCES employees(employee_id),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE inventory_reservations (
    reservation_id INTEGER PRIMARY KEY,
    sales_order_item_id INTEGER,
    lot_id INTEGER NOT NULL REFERENCES inventory_lots(lot_id),
    reserved_quantity_stems NUMERIC NOT NULL CHECK (reserved_quantity_stems > 0),
    released_quantity_stems NUMERIC NOT NULL DEFAULT 0 CHECK (released_quantity_stems >= 0),
    reservation_date TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','partially_released','released','fulfilled')),
    CHECK (released_quantity_stems <= reserved_quantity_stems)
);

CREATE TABLE quality_inspections (
    inspection_id INTEGER PRIMARY KEY,
    lot_id INTEGER NOT NULL REFERENCES inventory_lots(lot_id),
    inspection_date TEXT NOT NULL,
    inspected_by INTEGER REFERENCES employees(employee_id),
    grade_observed TEXT,
    condition_score INTEGER CHECK (condition_score IS NULL OR condition_score BETWEEN 1 AND 5),
    rejected_quantity_stems NUMERIC NOT NULL DEFAULT 0 CHECK (rejected_quantity_stems >= 0),
    temperature_c NUMERIC,
    notes TEXT
);

CREATE TABLE waste_records (
    waste_id INTEGER PRIMARY KEY,
    lot_id INTEGER NOT NULL REFERENCES inventory_lots(lot_id),
    waste_date TEXT NOT NULL,
    quantity_stems NUMERIC NOT NULL CHECK (quantity_stems > 0),
    reason TEXT NOT NULL CHECK (reason IN ('expired','damaged','quality_rejection','temperature_excursion','unsold','handling_error','other')),
    estimated_cost_usd NUMERIC NOT NULL DEFAULT 0 CHECK (estimated_cost_usd >= 0),
    notes TEXT
);

CREATE TABLE inventory_transfers (
    transfer_id INTEGER PRIMARY KEY,
    transfer_number TEXT NOT NULL UNIQUE,
    from_warehouse_id INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    to_warehouse_id INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    transfer_date TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN ('requested','in_transit','received','cancelled')),
    notes TEXT,
    CHECK (from_warehouse_id <> to_warehouse_id)
);

CREATE TABLE inventory_transfer_items (
    transfer_item_id INTEGER PRIMARY KEY,
    transfer_id INTEGER NOT NULL REFERENCES inventory_transfers(transfer_id),
    lot_id INTEGER NOT NULL REFERENCES inventory_lots(lot_id),
    quantity_stems NUMERIC NOT NULL CHECK (quantity_stems > 0),
    received_quantity_stems NUMERIC CHECK (received_quantity_stems IS NULL OR received_quantity_stems >= 0)
);

CREATE TABLE sales_orders (
    sales_order_id INTEGER PRIMARY KEY,
    so_number TEXT NOT NULL UNIQUE,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    order_date TEXT NOT NULL,
    requested_delivery_date TEXT,
    sales_channel TEXT NOT NULL CHECK (sales_channel IN ('wholesale','retail','phone','email','online','other')),
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','confirmed','partially_fulfilled','fulfilled','cancelled')),
    notes TEXT,
    created_by INTEGER REFERENCES employees(employee_id)
);

CREATE TABLE sales_order_items (
    sales_order_item_id INTEGER PRIMARY KEY,
    sales_order_id INTEGER NOT NULL REFERENCES sales_orders(sales_order_id),
    line_number INTEGER NOT NULL,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    quantity_ordered NUMERIC NOT NULL CHECK (quantity_ordered > 0),
    uom_code TEXT NOT NULL REFERENCES units_of_measure(uom_code),
    stems_per_unit NUMERIC NOT NULL CHECK (stems_per_unit > 0),
    unit_selling_price NUMERIC NOT NULL CHECK (unit_selling_price >= 0),
    discount_amount NUMERIC NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    UNIQUE(sales_order_id, line_number)
);

CREATE TABLE sales_order_fulfillments (
    fulfillment_id INTEGER PRIMARY KEY,
    fulfillment_number TEXT NOT NULL UNIQUE,
    sales_order_id INTEGER NOT NULL REFERENCES sales_orders(sales_order_id),
    fulfillment_date TEXT NOT NULL,
    warehouse_id INTEGER NOT NULL REFERENCES warehouses(warehouse_id),
    status TEXT NOT NULL DEFAULT 'prepared' CHECK (status IN ('prepared','dispatched','delivered','cancelled')),
    delivery_notes TEXT
);

CREATE TABLE sales_order_fulfillment_items (
    fulfillment_item_id INTEGER PRIMARY KEY,
    fulfillment_id INTEGER NOT NULL REFERENCES sales_order_fulfillments(fulfillment_id),
    sales_order_item_id INTEGER NOT NULL REFERENCES sales_order_items(sales_order_item_id),
    lot_id INTEGER NOT NULL REFERENCES inventory_lots(lot_id),
    quantity_fulfilled_units NUMERIC NOT NULL CHECK (quantity_fulfilled_units > 0),
    quantity_fulfilled_stems NUMERIC NOT NULL CHECK (quantity_fulfilled_stems > 0)
);

CREATE TABLE sales_invoices (
    sales_invoice_id INTEGER PRIMARY KEY,
    invoice_number TEXT NOT NULL UNIQUE,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    sales_order_id INTEGER REFERENCES sales_orders(sales_order_id),
    invoice_date TEXT NOT NULL,
    due_date TEXT NOT NULL,
    currency_code TEXT NOT NULL DEFAULT 'USD' REFERENCES currencies(currency_code),
    subtotal NUMERIC NOT NULL CHECK (subtotal >= 0),
    discount_total NUMERIC NOT NULL DEFAULT 0 CHECK (discount_total >= 0),
    tax_total NUMERIC NOT NULL DEFAULT 0 CHECK (tax_total >= 0),
    shipping_total NUMERIC NOT NULL DEFAULT 0 CHECK (shipping_total >= 0),
    total_amount NUMERIC NOT NULL CHECK (total_amount >= 0),
    status TEXT NOT NULL DEFAULT 'posted' CHECK (status IN ('draft','posted','partially_paid','paid','void','overdue')),
    CHECK (due_date >= invoice_date)
);

CREATE TABLE sales_invoice_items (
    sales_invoice_item_id INTEGER PRIMARY KEY,
    sales_invoice_id INTEGER NOT NULL REFERENCES sales_invoices(sales_invoice_id),
    sales_order_item_id INTEGER REFERENCES sales_order_items(sales_order_item_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    quantity NUMERIC NOT NULL CHECK (quantity > 0),
    uom_code TEXT NOT NULL REFERENCES units_of_measure(uom_code),
    stems_sold NUMERIC NOT NULL CHECK (stems_sold > 0),
    unit_price NUMERIC NOT NULL CHECK (unit_price >= 0),
    line_discount NUMERIC NOT NULL DEFAULT 0 CHECK (line_discount >= 0),
    line_total NUMERIC NOT NULL CHECK (line_total >= 0)
);

CREATE TABLE customer_returns (
    customer_return_id INTEGER PRIMARY KEY,
    return_number TEXT NOT NULL UNIQUE,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    sales_invoice_id INTEGER REFERENCES sales_invoices(sales_invoice_id),
    return_date TEXT NOT NULL,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN ('requested','approved','received','rejected','credited'))
);

CREATE TABLE customer_return_items (
    customer_return_item_id INTEGER PRIMARY KEY,
    customer_return_id INTEGER NOT NULL REFERENCES customer_returns(customer_return_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    lot_id INTEGER REFERENCES inventory_lots(lot_id),
    quantity_stems NUMERIC NOT NULL CHECK (quantity_stems > 0),
    restockable INTEGER NOT NULL DEFAULT 0 CHECK (restockable IN (0,1)),
    condition_notes TEXT
);

CREATE TABLE sales_credits (
    sales_credit_id INTEGER PRIMARY KEY,
    credit_number TEXT NOT NULL UNIQUE,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    sales_invoice_id INTEGER REFERENCES sales_invoices(sales_invoice_id),
    credit_date TEXT NOT NULL,
    amount NUMERIC NOT NULL CHECK (amount >= 0),
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'posted' CHECK (status IN ('draft','posted','void'))
);

CREATE TABLE product_prices (
    product_price_id INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    customer_type TEXT NOT NULL CHECK (customer_type IN ('wholesale_florist','event_planner','retailer','individual','all')),
    uom_code TEXT NOT NULL REFERENCES units_of_measure(uom_code),
    currency_code TEXT NOT NULL REFERENCES currencies(currency_code),
    price NUMERIC NOT NULL CHECK (price >= 0),
    valid_from TEXT NOT NULL,
    valid_to TEXT,
    CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

CREATE TABLE customer_price_lists (
    price_list_id INTEGER PRIMARY KEY,
    price_list_name TEXT NOT NULL UNIQUE,
    currency_code TEXT NOT NULL REFERENCES currencies(currency_code),
    valid_from TEXT NOT NULL,
    valid_to TEXT
);

CREATE TABLE customer_price_list_items (
    price_list_item_id INTEGER PRIMARY KEY,
    price_list_id INTEGER NOT NULL REFERENCES customer_price_lists(price_list_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    uom_code TEXT NOT NULL REFERENCES units_of_measure(uom_code),
    unit_price NUMERIC NOT NULL CHECK (unit_price >= 0),
    UNIQUE(price_list_id, product_id, uom_code)
);

CREATE TABLE supplier_invoices (
    supplier_invoice_id INTEGER PRIMARY KEY,
    supplier_id INTEGER NOT NULL REFERENCES suppliers(supplier_id),
    supplier_invoice_number TEXT NOT NULL,
    purchase_order_id INTEGER REFERENCES purchase_orders(purchase_order_id),
    shipment_id INTEGER REFERENCES shipments(shipment_id),
    invoice_date TEXT NOT NULL,
    due_date TEXT NOT NULL,
    currency_code TEXT NOT NULL REFERENCES currencies(currency_code),
    subtotal NUMERIC NOT NULL CHECK (subtotal >= 0),
    charges_total NUMERIC NOT NULL DEFAULT 0 CHECK (charges_total >= 0),
    credit_total NUMERIC NOT NULL DEFAULT 0 CHECK (credit_total >= 0),
    total_amount NUMERIC NOT NULL CHECK (total_amount >= 0),
    status TEXT NOT NULL DEFAULT 'posted' CHECK (status IN ('draft','posted','partially_paid','paid','disputed','void')),
    UNIQUE(supplier_id, supplier_invoice_number),
    CHECK (due_date >= invoice_date)
);

CREATE TABLE supplier_invoice_items (
    supplier_invoice_item_id INTEGER PRIMARY KEY,
    supplier_invoice_id INTEGER NOT NULL REFERENCES supplier_invoices(supplier_invoice_id),
    product_id INTEGER REFERENCES products(product_id),
    description TEXT NOT NULL,
    quantity NUMERIC,
    uom_code TEXT REFERENCES units_of_measure(uom_code),
    unit_price NUMERIC NOT NULL CHECK (unit_price >= 0),
    line_total NUMERIC NOT NULL CHECK (line_total >= 0)
);

CREATE TABLE supplier_payments (
    supplier_payment_id INTEGER PRIMARY KEY,
    payment_reference TEXT NOT NULL UNIQUE,
    supplier_id INTEGER NOT NULL REFERENCES suppliers(supplier_id),
    payment_date TEXT NOT NULL,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    currency_code TEXT NOT NULL REFERENCES currencies(currency_code),
    payment_method TEXT NOT NULL CHECK (payment_method IN ('bank_transfer','card','check','cash','other')),
    status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('pending','completed','void')),
    notes TEXT
);

CREATE TABLE supplier_payment_allocations (
    supplier_payment_allocation_id INTEGER PRIMARY KEY,
    supplier_payment_id INTEGER NOT NULL REFERENCES supplier_payments(supplier_payment_id),
    supplier_invoice_id INTEGER NOT NULL REFERENCES supplier_invoices(supplier_invoice_id),
    amount_allocated NUMERIC NOT NULL CHECK (amount_allocated > 0),
    UNIQUE(supplier_payment_id, supplier_invoice_id)
);

CREATE TABLE supplier_credit_notes (
    supplier_credit_note_id INTEGER PRIMARY KEY,
    supplier_id INTEGER NOT NULL REFERENCES suppliers(supplier_id),
    supplier_invoice_id INTEGER REFERENCES supplier_invoices(supplier_invoice_id),
    credit_note_number TEXT NOT NULL,
    credit_date TEXT NOT NULL,
    amount NUMERIC NOT NULL CHECK (amount >= 0),
    reason TEXT NOT NULL,
    UNIQUE(supplier_id, credit_note_number)
);

CREATE TABLE customer_payments (
    customer_payment_id INTEGER PRIMARY KEY,
    payment_reference TEXT NOT NULL UNIQUE,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    payment_date TEXT NOT NULL,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    currency_code TEXT NOT NULL REFERENCES currencies(currency_code),
    payment_method TEXT NOT NULL CHECK (payment_method IN ('bank_transfer','card','check','cash','other')),
    status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('pending','completed','void')),
    notes TEXT
);

CREATE TABLE customer_payment_allocations (
    customer_payment_allocation_id INTEGER PRIMARY KEY,
    customer_payment_id INTEGER NOT NULL REFERENCES customer_payments(customer_payment_id),
    sales_invoice_id INTEGER NOT NULL REFERENCES sales_invoices(sales_invoice_id),
    amount_allocated NUMERIC NOT NULL CHECK (amount_allocated > 0),
    UNIQUE(customer_payment_id, sales_invoice_id)
);

CREATE TABLE customer_refunds (
    customer_refund_id INTEGER PRIMARY KEY,
    refund_reference TEXT NOT NULL UNIQUE,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    refund_date TEXT NOT NULL,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    currency_code TEXT NOT NULL REFERENCES currencies(currency_code),
    reason TEXT NOT NULL
);

CREATE TABLE chart_of_accounts (
    account_id INTEGER PRIMARY KEY,
    account_code TEXT NOT NULL UNIQUE,
    account_name TEXT NOT NULL,
    account_type TEXT NOT NULL CHECK (account_type IN ('asset','liability','equity','revenue','expense','contra_revenue','contra_asset')),
    parent_account_id INTEGER REFERENCES chart_of_accounts(account_id),
    active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1))
);

CREATE TABLE journal_entries (
    journal_entry_id INTEGER PRIMARY KEY,
    entry_number TEXT NOT NULL UNIQUE,
    entry_date TEXT NOT NULL,
    description TEXT NOT NULL,
    source_type TEXT,
    source_id INTEGER,
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','posted','reversed')),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE journal_entry_lines (
    journal_line_id INTEGER PRIMARY KEY,
    journal_entry_id INTEGER NOT NULL REFERENCES journal_entries(journal_entry_id),
    account_id INTEGER NOT NULL REFERENCES chart_of_accounts(account_id),
    debit NUMERIC NOT NULL DEFAULT 0 CHECK (debit >= 0),
    credit NUMERIC NOT NULL DEFAULT 0 CHECK (credit >= 0),
    description TEXT,
    CHECK (NOT (debit > 0 AND credit > 0)),
    CHECK (debit > 0 OR credit > 0)
);

CREATE TABLE bank_accounts (
    bank_account_id INTEGER PRIMARY KEY,
    account_name TEXT NOT NULL,
    bank_name TEXT NOT NULL,
    currency_code TEXT NOT NULL REFERENCES currencies(currency_code),
    account_last_four TEXT,
    active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1))
);

CREATE TABLE bank_transactions (
    bank_transaction_id INTEGER PRIMARY KEY,
    bank_account_id INTEGER NOT NULL REFERENCES bank_accounts(bank_account_id),
    transaction_date TEXT NOT NULL,
    description TEXT NOT NULL,
    amount NUMERIC NOT NULL,
    currency_code TEXT NOT NULL REFERENCES currencies(currency_code),
    external_reference TEXT,
    reconciled INTEGER NOT NULL DEFAULT 0 CHECK (reconciled IN (0,1))
);

CREATE TABLE bank_reconciliations (
    bank_reconciliation_id INTEGER PRIMARY KEY,
    bank_account_id INTEGER NOT NULL REFERENCES bank_accounts(bank_account_id),
    statement_start_date TEXT NOT NULL,
    statement_end_date TEXT NOT NULL,
    statement_balance NUMERIC NOT NULL,
    completed_at TEXT,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','completed')),
    CHECK (statement_end_date >= statement_start_date)
);

CREATE TABLE shipment_tracking_events (
    tracking_event_id INTEGER PRIMARY KEY,
    shipment_id INTEGER NOT NULL REFERENCES shipments(shipment_id),
    event_time TEXT NOT NULL,
    event_type TEXT NOT NULL,
    location TEXT,
    temperature_c NUMERIC,
    notes TEXT
);

CREATE TABLE delivery_orders (
    delivery_order_id INTEGER PRIMARY KEY,
    delivery_number TEXT NOT NULL UNIQUE,
    sales_order_id INTEGER NOT NULL REFERENCES sales_orders(sales_order_id),
    carrier_id INTEGER REFERENCES carriers(carrier_id),
    scheduled_date TEXT,
    dispatched_at TEXT,
    delivered_at TEXT,
    status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','dispatched','delivered','failed','cancelled')),
    delivery_address TEXT,
    notes TEXT
);

CREATE TABLE delivery_order_items (
    delivery_order_item_id INTEGER PRIMARY KEY,
    delivery_order_id INTEGER NOT NULL REFERENCES delivery_orders(delivery_order_id),
    fulfillment_item_id INTEGER REFERENCES sales_order_fulfillment_items(fulfillment_item_id),
    quantity_stems NUMERIC NOT NULL CHECK (quantity_stems > 0)
);

CREATE TABLE delivery_confirmations (
    delivery_confirmation_id INTEGER PRIMARY KEY,
    delivery_order_id INTEGER NOT NULL REFERENCES delivery_orders(delivery_order_id),
    confirmed_at TEXT NOT NULL,
    received_by_name TEXT,
    condition_status TEXT NOT NULL CHECK (condition_status IN ('good','partial_damage','damaged','rejected')),
    notes TEXT
);

CREATE TABLE quality_claims (
    quality_claim_id INTEGER PRIMARY KEY,
    supplier_id INTEGER REFERENCES suppliers(supplier_id),
    shipment_id INTEGER REFERENCES shipments(shipment_id),
    lot_id INTEGER REFERENCES inventory_lots(lot_id),
    claim_date TEXT NOT NULL,
    claim_type TEXT NOT NULL CHECK (claim_type IN ('damage','shortage','quality','temperature','other')),
    claimed_amount NUMERIC NOT NULL DEFAULT 0 CHECK (claimed_amount >= 0),
    currency_code TEXT NOT NULL DEFAULT 'USD' REFERENCES currencies(currency_code),
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','submitted','accepted','rejected','settled')),
    resolution_notes TEXT
);

CREATE TABLE audit_log (
    audit_id INTEGER PRIMARY KEY,
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    action TEXT NOT NULL CHECK (action IN ('INSERT','UPDATE','DELETE','POST','REVERSE')),
    changed_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by INTEGER REFERENCES employees(employee_id),
    old_values_json TEXT,
    new_values_json TEXT,
    reason TEXT
);

CREATE TABLE app_users (
    app_user_id INTEGER PRIMARY KEY,
    employee_id INTEGER REFERENCES employees(employee_id),
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT,
    role_name TEXT NOT NULL CHECK (role_name IN ('admin','purchasing','warehouse','sales','accounting','read_only')),
    active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Reporting views
CREATE VIEW v_inventory_by_lot AS
SELECT l.lot_id, l.lot_code, p.sku, p.product_name, p.variety, p.color,
       c.country_name AS origin_country, s.supplier_name,
       w.warehouse_name, sl.location_code, l.received_date, l.estimated_sell_by_date,
       l.initial_quantity_stems,
       COALESCE(SUM(CASE
         WHEN t.transaction_type IN ('receipt','transfer_in','adjustment_in','return') THEN t.quantity_stems
         WHEN t.transaction_type IN ('sale','transfer_out','damage','waste','adjustment_out') THEN -t.quantity_stems
         ELSE 0 END), l.initial_quantity_stems) AS calculated_on_hand_stems,
       l.unit_cost_usd,
       l.quality_status
FROM inventory_lots l
JOIN products p ON p.product_id = l.product_id
JOIN countries c ON c.country_code = l.origin_country_code
LEFT JOIN suppliers s ON s.supplier_id = l.supplier_id
JOIN warehouses w ON w.warehouse_id = l.warehouse_id
LEFT JOIN storage_locations sl ON sl.location_id = l.location_id
LEFT JOIN inventory_transactions t ON t.lot_id = l.lot_id
GROUP BY l.lot_id, l.lot_code, p.sku, p.product_name, p.variety, p.color,
         c.country_name, s.supplier_name, w.warehouse_name, sl.location_code,
         l.received_date, l.estimated_sell_by_date, l.initial_quantity_stems,
         l.unit_cost_usd, l.quality_status;

CREATE VIEW v_accounts_receivable_aging AS
SELECT i.sales_invoice_id, i.invoice_number, c.customer_name, i.invoice_date, i.due_date,
       i.currency_code, i.total_amount,
       i.total_amount
       - COALESCE((SELECT SUM(a.amount_allocated)
                   FROM customer_payment_allocations a
                   JOIN customer_payments p ON p.customer_payment_id = a.customer_payment_id
                   WHERE a.sales_invoice_id = i.sales_invoice_id AND p.status = 'completed'), 0)
       - COALESCE((SELECT SUM(cr.amount) FROM sales_credits cr
                   WHERE cr.sales_invoice_id = i.sales_invoice_id AND cr.status = 'posted'), 0)
       AS outstanding_amount,
       CASE
         WHEN date('now') <= i.due_date THEN 'current'
         WHEN julianday(date('now')) - julianday(i.due_date) <= 30 THEN '1-30 days'
         WHEN julianday(date('now')) - julianday(i.due_date) <= 60 THEN '31-60 days'
         WHEN julianday(date('now')) - julianday(i.due_date) <= 90 THEN '61-90 days'
         ELSE 'over 90 days'
       END AS aging_bucket
FROM sales_invoices i JOIN customers c ON c.customer_id = i.customer_id
WHERE i.status NOT IN ('draft','void');

CREATE VIEW v_accounts_payable_aging AS
SELECT i.supplier_invoice_id, i.supplier_invoice_number, s.supplier_name, i.invoice_date, i.due_date,
       i.currency_code, i.total_amount,
       i.total_amount
       - COALESCE((SELECT SUM(a.amount_allocated)
                   FROM supplier_payment_allocations a
                   JOIN supplier_payments p ON p.supplier_payment_id = a.supplier_payment_id
                   WHERE a.supplier_invoice_id = i.supplier_invoice_id AND p.status = 'completed'), 0)
       - COALESCE((SELECT SUM(cn.amount) FROM supplier_credit_notes cn
                   WHERE cn.supplier_invoice_id = i.supplier_invoice_id), 0)
       AS outstanding_amount,
       CASE
         WHEN date('now') <= i.due_date THEN 'current'
         WHEN julianday(date('now')) - julianday(i.due_date) <= 30 THEN '1-30 days'
         WHEN julianday(date('now')) - julianday(i.due_date) <= 60 THEN '31-60 days'
         WHEN julianday(date('now')) - julianday(i.due_date) <= 90 THEN '61-90 days'
         ELSE 'over 90 days'
       END AS aging_bucket
FROM supplier_invoices i JOIN suppliers s ON s.supplier_id = i.supplier_id
WHERE i.status NOT IN ('draft','void');

CREATE VIEW v_sales_by_product AS
SELECT p.product_id, p.sku, p.product_name, p.variety,
       SUM(ii.quantity) AS units_sold,
       SUM(ii.stems_sold) AS stems_sold,
       SUM(ii.line_total) AS sales_revenue
FROM sales_invoice_items ii
JOIN products p ON p.product_id = ii.product_id
JOIN sales_invoices i ON i.sales_invoice_id = ii.sales_invoice_id
WHERE i.status NOT IN ('draft','void')
GROUP BY p.product_id, p.sku, p.product_name, p.variety;

CREATE VIEW v_monthly_sales AS
SELECT substr(invoice_date,1,7) AS sales_month,
       COUNT(*) AS invoice_count,
       SUM(total_amount) AS invoiced_amount
FROM sales_invoices
WHERE status NOT IN ('draft','void')
GROUP BY substr(invoice_date,1,7);

CREATE VIEW v_supplier_spend AS
SELECT s.supplier_id, s.supplier_name, s.country_code,
       COUNT(i.supplier_invoice_id) AS invoice_count,
       COALESCE(SUM(i.total_amount),0) AS invoiced_amount,
       i.currency_code
FROM suppliers s LEFT JOIN supplier_invoices i ON i.supplier_id = s.supplier_id
GROUP BY s.supplier_id, s.supplier_name, s.country_code, i.currency_code;

CREATE VIEW v_waste_by_product AS
SELECT p.product_id, p.sku, p.product_name,
       SUM(wr.quantity_stems) AS wasted_stems,
       SUM(wr.estimated_cost_usd) AS estimated_waste_cost_usd
FROM waste_records wr JOIN inventory_lots l ON l.lot_id = wr.lot_id
JOIN products p ON p.product_id = l.product_id
GROUP BY p.product_id, p.sku, p.product_name;

CREATE VIEW v_journal_entry_balance AS
SELECT je.journal_entry_id, je.entry_number, je.entry_date, je.status,
       COALESCE(SUM(jl.debit),0) AS total_debits,
       COALESCE(SUM(jl.credit),0) AS total_credits,
       COALESCE(SUM(jl.debit),0) - COALESCE(SUM(jl.credit),0) AS difference
FROM journal_entries je LEFT JOIN journal_entry_lines jl ON jl.journal_entry_id = je.journal_entry_id
GROUP BY je.journal_entry_id, je.entry_number, je.entry_date, je.status;

CREATE INDEX idx_po_supplier_date ON purchase_orders(supplier_id, order_date);
CREATE INDEX idx_shipment_arrival ON shipments(expected_arrival_date, status);
CREATE INDEX idx_inventory_lots_product ON inventory_lots(product_id, received_date);
CREATE INDEX idx_inventory_tx_lot_date ON inventory_transactions(lot_id, transaction_date);
CREATE INDEX idx_sales_order_customer_date ON sales_orders(customer_id, order_date);
CREATE INDEX idx_sales_invoice_customer_due ON sales_invoices(customer_id, due_date, status);
CREATE INDEX idx_supplier_invoice_supplier_due ON supplier_invoices(supplier_id, due_date, status);
CREATE INDEX idx_receipt_shipment ON goods_receipts(shipment_id, received_at);
CREATE INDEX idx_tracking_shipment_time ON shipment_tracking_events(shipment_id, event_time);
