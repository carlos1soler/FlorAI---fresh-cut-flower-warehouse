from pathlib import Path
import sqlite3
from datetime import date

import numpy as np
import pandas as pd
import streamlit as st

# ---------------------------------------------------------------------------
# Page config
# ---------------------------------------------------------------------------
st.set_page_config(
    page_title="FlorAI | Inventory Intelligence",
    page_icon="🌷",
    layout="wide",
    initial_sidebar_state="expanded",
)

DB_PATH = Path(__file__).parent / "data" / "florai.db"

# ---------------------------------------------------------------------------
# Strict Dark Theme & Typography
# ---------------------------------------------------------------------------
st.markdown(
    """
    <style>
      /* 1. GLOBAL PAGE & TYPOGRAPHY */
      .stApp {
          background-color: #0E1117 !important;
          color: #FFFFFF !important;
      }
      html, body, [class*="css"] {
          font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif !important;
          font-size: 15px !important;
      }
      h1, h2, h3, h4, h5, h6 {
          color: #FFFFFF !important;
      }
      p, span, label, li {
          color: #E0E0E0 !important;
      }
      
      /* 2. SIDEBAR */
      section[data-testid="stSidebar"] {
          background-color: #151A22 !important;
          border-right: 1px solid #2D3748 !important;
      }
      /* Force all text in sidebar to be light */
      section[data-testid="stSidebar"] * {
          color: #F8F9FA !important;
      }
      section[data-testid="stSidebar"] div[role="radiogroup"] label p {
          font-size: 15px !important;
          font-weight: 600 !important;
      }
      
      /* 3. TABLES (DataFrames) - High Contrast */
      div[data-testid="stDataFrame"] {
          border: 1px solid #2D3748 !important;
          border-radius: 8px;
          background-color: #1A202C !important;
      }
      div[data-testid="stDataFrame"] div {
          color: #F8F9FA !important; /* White text for data */
      }
      div[data-testid="stDataFrame"] [role="columnheader"] {
          background-color: #2D3748 !important;
          color: #FFFFFF !important;
          font-weight: 700 !important;
      }
      div[data-testid="stDataFrame"] [role="gridcell"] {
          background-color: #1A202C !important;
          color: #F8F9FA !important;
      }
      
      /* 4. METRIC CARDS (KPI) */
      div[data-testid="stMetric"] {
          background-color: #1A202C !important;
          border: 1px solid #2D3748 !important;
          border-radius: 12px;
          padding: 20px;
          box-shadow: 0 4px 6px rgba(0,0,0,0.2);
      }
      div[data-testid="stMetricLabel"] p {
          color: #A0AEC0 !important;
          font-size: 14px !important;
          font-weight: 600 !important;
          text-transform: uppercase;
          letter-spacing: 0.5px;
      }
      /* KPI VALUES - Set to 14px as requested */
      div[data-testid="stMetricValue"] div {
          color: #FFFFFF !important; 
          font-size: 14px !important; 
          font-weight: 600 !important;
      }
      
      /* 5. INPUTS & SELECTS */
      div[data-baseweb="select"] > div {
          background-color: #1A202C !important;
          border-color: #4A5568 !important;
      }
      div[data-baseweb="select"] * {
          color: #FFFFFF !important;
      }
      input {
          background-color: #1A202C !important;
          color: #FFFFFF !important;
          border-color: #4A5568 !important;
      }
      
      /* 6. CUSTOM SECTION TITLES */
      .section-title {
          font-size: 1.4rem; 
          font-weight: 700; 
          color: #FFFFFF !important; 
          margin: 1.5rem 0 1rem 0;
          padding-bottom: 0.5rem;
          border-bottom: 2px solid #2D3748;
      }
      
      /* 7. BUTTONS */
      div.stDownloadButton > button {
          background-color: #2B6CB0 !important; 
          color: #FFFFFF !important; 
          border-radius: 8px;
          border: none;
          font-weight: 600;
      }
      div.stDownloadButton > button:hover {
          background-color: #3182CE !important; 
      }
      
      /* 8. TABS */
      button[data-baseweb="tab"] * {
          color: #A0AEC0 !important;
          font-size: 15px !important;
          font-weight: 600 !important;
      }
      button[data-baseweb="tab"][aria-selected="true"] * {
          color: #FFFFFF !important;
          font-weight: 800 !important;
      }
      div[data-baseweb="tab-highlight"] {
          background-color: #3182CE !important;
      }
      
      /* 9. ALERTS */
      div[data-testid="stAlert"] {
          background-color: #1A202C !important;
          border: 1px solid #2D3748 !important;
      }
      div[data-testid="stAlert"] * {
          color: #E0E0E0 !important;
      }
    </style>
    """,
    unsafe_allow_html=True,
)


# ---------------------------------------------------------------------------
# Data access
# ---------------------------------------------------------------------------
@st.cache_data(ttl=30)
def query_df(sql: str) -> pd.DataFrame:
    if not DB_PATH.is_file():
        raise FileNotFoundError(f"Database file not found: {DB_PATH}")
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute("PRAGMA query_only = ON")
        return pd.read_sql_query(sql, conn)


def try_query(sql: str) -> pd.DataFrame:
    try:
        return query_df(sql)
    except Exception:
        return pd.DataFrame()


def money(value: float, currency: str = "$") -> str:
    try:
        return f"{currency}{float(value):,.0f}"
    except (TypeError, ValueError):
        return f"{currency}0"


def num(value) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


# ---------------------------------------------------------------------------
# Load core data
# ---------------------------------------------------------------------------
st.title("🌷 FlorAI")
st.caption("Inventory intelligence for a fresh-cut flower wholesaler · read-only for portfolio purpose")
st.caption("Freshness tracking starts at the cut date. Shelf-life profiles are illustrative planning estimates, not guarantees; inspect flowers and account for cold-chain conditions.")

if not DB_PATH.is_file():
    st.error(f"Database file not found: {DB_PATH}")
    st.info("Confirm that the database file exists at `data/florai.db` relative to `app.py`.")
    st.stop()

inventory = try_query(
    """
    SELECT lot_id, lot_code, sku, product_name, variety, color,
           origin_country, supplier_name, warehouse_name, location_code,
           cut_date, received_date, estimated_sell_by_date, typical_life_days_after_cut,
           initial_quantity_stems, calculated_on_hand_stems, unit_cost_usd, quality_status
    FROM v_inventory_by_lot
    WHERE COALESCE(calculated_on_hand_stems, 0) > 0
    ORDER BY received_date, product_name
    """
)

if inventory.empty:
    st.warning("No inventory lots with positive stock were found, or the inventory view is unavailable.")
    st.stop()

inventory["cut_date"] = pd.to_datetime(inventory["cut_date"], errors="coerce")
inventory["received_date"] = pd.to_datetime(inventory["received_date"], errors="coerce")
inventory["estimated_sell_by_date"] = pd.to_datetime(
    inventory["estimated_sell_by_date"], errors="coerce"
)
inventory["typical_life_days_after_cut"] = pd.to_numeric(inventory["typical_life_days_after_cut"], errors="coerce")
inventory["calculated_on_hand_stems"] = pd.to_numeric(
    inventory["calculated_on_hand_stems"], errors="coerce"
).fillna(0)
inventory["unit_cost_usd"] = pd.to_numeric(
    inventory["unit_cost_usd"], errors="coerce"
).fillna(0)


# ---------------------------------------------------------------------------
# Sidebar navigation & global settings
# ---------------------------------------------------------------------------
with st.sidebar:
    st.header("Navigation")
    page = st.radio(
        "Go to",
        [
            "Overview",
            "Inventory explorer",
            "Lot deep-dive",
            "Pricing & margins",
            "Sales analytics",
            "Waste & quality",
            "Supplier & purchasing",
            "AR / AP aging",
        ],
        label_visibility="collapsed",
    )

    st.divider()
    st.header("Analysis settings")
    reference_date = st.date_input("Analysis date", value=date.today())
    regular_days = st.slider(
        "Regular-price window (days)", 1, 14, 7,
        help="Lots at or below this age keep the regular price.",
    )
    urgent_days = st.slider(
        "Urgent review from day", 8, 30, 15,
        help="At this age or older, prioritize immediate sale and quality check.",
    )
    if urgent_days <= regular_days:
        st.error("Urgent review must start after the regular-price window.")
        st.stop()

    st.divider()
    st.header("Filters")
    warehouse_options = ["All warehouses"] + sorted(
        inventory["warehouse_name"].dropna().unique().tolist()
    )
    selected_warehouse_global = st.selectbox("Warehouse", warehouse_options)


inventory_base = inventory.copy()
if selected_warehouse_global != "All warehouses":
    inventory_base = inventory_base[inventory_base["warehouse_name"] == selected_warehouse_global]

if inventory_base.empty:
    st.warning("No stock in the selected warehouse.")
    st.stop()


# ---------------------------------------------------------------------------
# Derived columns & classification
# ---------------------------------------------------------------------------
analysis_timestamp = pd.Timestamp(reference_date)
inventory_base["days_since_cut"] = (analysis_timestamp - inventory_base["cut_date"].dt.normalize()).dt.days
inventory_base["days_from_cut_to_receipt"] = (inventory_base["received_date"].dt.normalize() - inventory_base["cut_date"].dt.normalize()).dt.days
inventory_base["estimated_days_remaining_after_cut"] = (inventory_base["estimated_sell_by_date"].dt.normalize() - analysis_timestamp).dt.days
inventory_base["days_in_inventory"] = (
    analysis_timestamp - inventory_base["received_date"].dt.normalize()
).dt.days
inventory_base["days_until_sell_by"] = (
    inventory_base["estimated_sell_by_date"].dt.normalize() - analysis_timestamp
).dt.days
inventory_base["estimated_stock_cost"] = (
    inventory_base["calculated_on_hand_stems"] * inventory_base["unit_cost_usd"]
)


def classify(row: pd.Series) -> str:
    age = row["days_in_inventory"]
    sell_by = row["days_until_sell_by"]
    quality = (
        str(row["quality_status"]).strip().lower()
        if pd.notna(row["quality_status"])
        else ""
    )

    if quality not in {"accepted", "good", "ok", "available"}:
        return "Quality review"
    if pd.notna(sell_by) and sell_by < 0:
        return "Past sell-by date"
    if pd.notna(sell_by) and sell_by <= 2:
        return "Sell urgently"
    if pd.isna(age) or age < 0:
        return "Check receipt date"
    if age >= urgent_days:
        return "Urgent sale / quality review"
    if age > regular_days:
        return "Promote / discount"
    return "Regular price"


inventory_base["product_status"] = inventory_base.apply(classify, axis=1)

STATUS_ORDER = [
    "Past sell-by date",
    "Sell urgently",
    "Urgent sale / quality review",
    "Promote / discount",
    "Quality review",
    "Check receipt date",
    "Regular price",
]
PRIORITY_STATUSES = {
    "Past sell-by date",
    "Sell urgently",
    "Urgent sale / quality review",
    "Promote / discount",
}

STATUS_COLORS = {
    "Past sell-by date": "🔴",
    "Sell urgently": "🟠",
    "Urgent sale / quality review": "🟠",
    "Promote / discount": "🟡",
    "Quality review": "🟣",
    "Check receipt date": "🔵",
    "Regular price": "🟢",
}


def render_csv(df: pd.DataFrame, filename: str, key: str):
    csv = df.to_csv(index=False).encode("utf-8")
    st.download_button(
        "Download CSV",
        data=csv,
        file_name=filename,
        mime="text/csv",
        key=key,
    )


# ---------------------------------------------------------------------------
# PAGE: Overview
# ---------------------------------------------------------------------------
if page == "Overview":
    total_stems = int(inventory_base["calculated_on_hand_stems"].sum())
    stock_cost = float(inventory_base["estimated_stock_cost"].sum())
    products_count = int(inventory_base["sku"].nunique())
    lots_count = int(inventory_base["lot_code"].nunique())
    promo_stems = int(
        inventory_base.loc[
            inventory_base["product_status"].isin(PRIORITY_STATUSES),
            "calculated_on_hand_stems",
        ].sum()
    )
    urgent_stems = int(
        inventory_base.loc[
            inventory_base["product_status"].isin(
                {"Past sell-by date", "Sell urgently", "Urgent sale / quality review"}
            ),
            "calculated_on_hand_stems",
        ].sum()
    )

    st.markdown('<div class="section-title">Operational snapshot</div>', unsafe_allow_html=True)
    
    # 3x2 Grid Layout
    r1_c1, r1_c2, r1_c3 = st.columns(3)
    r1_c1.metric("Stems on hand", f"{total_stems:,}")
    r1_c2.metric("Active SKUs", f"{products_count:,}")
    r1_c3.metric("Active lots", f"{lots_count:,}")
    
    st.write("") 
    
    r2_c1, r2_c2, r2_c3 = st.columns(3)
    r2_c1.metric("Stock cost est.", money(stock_cost))
    r2_c2.metric("Stems to prioritize", f"{promo_stems:,}")
    r2_c3.metric("Urgent / expired", f"{urgent_stems:,}")

    st.caption(
        "Stock cost estimate = stems on hand × recorded unit cost (operational estimate, not a financial valuation). "
        f"Aging policy: 0–{regular_days}d regular · {regular_days+1}–{urgent_days-1}d discount · {urgent_days}d+ urgent review."
    )

    st.divider()
    st.markdown('<div class="section-title">Priority action list</div>', unsafe_allow_html=True)

    priority = inventory_base[
        inventory_base["product_status"].isin(PRIORITY_STATUSES | {"Quality review", "Check receipt date"})
    ].copy()
    priority["priority_rank"] = priority["product_status"].map(
        {s: i for i, s in enumerate(STATUS_ORDER)}
    )
    priority = priority.sort_values(
        ["priority_rank", "days_until_sell_by", "days_in_inventory"],
        ascending=[True, True, False],
        na_position="last",
    )
    priority["Action"] = priority["product_status"].map(
        lambda s: f"{STATUS_COLORS.get(s, '')} {s}".strip()
    )

    if priority.empty:
        st.success("No lots currently need a discount or urgent review.")
    else:
        show_cols = [
            "Action", "product_name", "variety", "color", "lot_code", "cut_date", "received_date", "days_since_cut",
            "calculated_on_hand_stems", "days_in_inventory", "days_until_sell_by",
            "warehouse_name", "quality_status",
        ]
        display = priority[show_cols].rename(columns={
            "product_name": "Flower",
            "variety": "Variety",
            "color": "Color",
            "lot_code": "Lot", "cut_date": "Cut date", "received_date": "Received", "days_since_cut": "Days since cut",
            "calculated_on_hand_stems": "Stems",
            "days_in_inventory": "Days in stock",
            "days_until_sell_by": "Days to sell-by",
            "warehouse_name": "Warehouse",
            "quality_status": "Quality",
        })
        st.dataframe(display, use_container_width=True, hide_index=True)

    left, right = st.columns(2)
    with left:
        st.markdown('<div class="section-title">Stock by flower (top 12)</div>', unsafe_allow_html=True)
        by_product = (
            inventory_base.groupby(["product_name", "variety"], as_index=False)
            .agg(
                stems_on_hand=("calculated_on_hand_stems", "sum"),
                stock_cost_estimate=("estimated_stock_cost", "sum"),
            )
            .sort_values("stems_on_hand", ascending=False)
            .head(12)
        )
        if not by_product.empty:
            st.bar_chart(
                by_product.set_index("product_name")[["stems_on_hand"]],
                horizontal=True,
                color="#5CB37B",
            )
            product_table = by_product.rename(columns={
                "product_name": "Flower",
                "variety": "Variety",
                "stems_on_hand": "Stems on hand",
                "stock_cost_estimate": "Est. stock cost",
            })
            product_table["Est. stock cost"] = product_table["Est. stock cost"].round(2)
            st.dataframe(product_table, use_container_width=True, hide_index=True)

    with right:
        st.markdown('<div class="section-title">Inventory age profile</div>', unsafe_allow_html=True)
        age_bins = [-np.inf, regular_days, urgent_days - 1, np.inf]
        age_labels = ["Regular price", "Promote / discount", "Urgent review"]
        age_group = pd.cut(inventory_base["days_in_inventory"], bins=age_bins, labels=age_labels)
        age_summary = (
            inventory_base.assign(age_group=age_group)
            .groupby("age_group", observed=False)["calculated_on_hand_stems"]
            .sum()
            .rename("Stems")
            .reset_index()
        )
        st.bar_chart(age_summary.set_index("age_group"), color="#5CB37B")
        st.dataframe(age_summary, use_container_width=True, hide_index=True)

    st.divider()
    st.markdown('<div class="section-title">Status breakdown</div>', unsafe_allow_html=True)
    status_summary = (
        inventory_base.groupby("product_status", as_index=False)
        .agg(
            lots=("lot_code", "nunique"),
            stems=("calculated_on_hand_stems", "sum"),
            cost=("estimated_stock_cost", "sum"),
        )
        .assign(rank=lambda d: d["product_status"].map({s: i for i, s in enumerate(STATUS_ORDER)}))
        .sort_values("rank")
        .drop(columns="rank")
    )
    status_summary["cost"] = status_summary["cost"].round(2)
    st.dataframe(
        status_summary.rename(columns={
            "product_status": "Status",
            "lots": "Lots",
            "stems": "Stems",
            "cost": "Est. cost",
        }),
        use_container_width=True,
        hide_index=True,
    )


# ---------------------------------------------------------------------------
# PAGE: Inventory explorer
# ---------------------------------------------------------------------------
elif page == "Inventory explorer":
    st.markdown('<div class="section-title">Inventory explorer</div>', unsafe_allow_html=True)

    f1, f2, f3, f4 = st.columns(4)
    with f1:
        product_options = ["All flowers"] + sorted(
            inventory_base["product_name"].dropna().unique().tolist()
        )
        selected_product = st.selectbox("Flower", product_options)
    with f2:
        status_options = ["All statuses"] + [
            s for s in STATUS_ORDER if s in inventory_base["product_status"].unique()
        ]
        selected_status = st.selectbox("Status", status_options)
    with f3:
        warehouse_options_local = ["All warehouses"] + sorted(
            inventory_base["warehouse_name"].dropna().unique().tolist()
        )
        selected_warehouse = st.selectbox("Warehouse", warehouse_options_local, key="explorer_wh")
    with f4:
        search = st.text_input("Search lot / SKU / variety", "")

    filtered = inventory_base.copy()
    if selected_product != "All flowers":
        filtered = filtered[filtered["product_name"] == selected_product]
    if selected_status != "All statuses":
        filtered = filtered[filtered["product_status"] == selected_status]
    if selected_warehouse != "All warehouses":
        filtered = filtered[filtered["warehouse_name"] == selected_warehouse]
    if search.strip():
        s = search.strip().lower()
        mask = (
            filtered["lot_code"].astype(str).str.lower().str.contains(s, na=False)
            | filtered["sku"].astype(str).str.lower().str.contains(s, na=False)
            | filtered["variety"].astype(str).str.lower().str.contains(s, na=False)
        )
        filtered = filtered[mask]

    st.write(f"**{len(filtered):,} lots** · {int(filtered['calculated_on_hand_stems'].sum()):,} stems")

    show_columns = [
        "lot_code", "sku", "product_name", "variety", "color", "origin_country",
        "supplier_name", "warehouse_name", "cut_date", "received_date", "estimated_sell_by_date", "typical_life_days_after_cut", "days_since_cut", "days_from_cut_to_receipt",
        "calculated_on_hand_stems", "days_in_inventory", "days_until_sell_by",
        "unit_cost_usd", "estimated_stock_cost", "product_status", "quality_status",
    ]
    show = filtered[show_columns].copy().rename(columns={
        "lot_code": "Lot", "sku": "SKU", "product_name": "Flower",
        "variety": "Variety", "color": "Color", "origin_country": "Origin",
        "supplier_name": "Supplier", "warehouse_name": "Warehouse",
        "cut_date": "Cut date", "received_date": "Received", "estimated_sell_by_date": "Estimated sell-by", "typical_life_days_after_cut": "Typical life after cut (days)", "days_since_cut": "Days since cut", "days_from_cut_to_receipt": "Transit days",
        "calculated_on_hand_stems": "Stems", "days_in_inventory": "Days in stock",
        "days_until_sell_by": "Days to sell-by", "unit_cost_usd": "Unit cost",
        "estimated_stock_cost": "Est. cost", "product_status": "Status",
        "quality_status": "Quality",
    })
    for col in ["Unit cost", "Est. cost"]:
        show[col] = show[col].round(2)
    show["Status"] = show["Status"].map(lambda s: f"{STATUS_COLORS.get(s, '')} {s}".strip())

    st.dataframe(show, use_container_width=True, hide_index=True, height=520)
    render_csv(show, "florai_inventory.csv", key="explorer_csv")


# ---------------------------------------------------------------------------
# PAGE: Lot deep-dive
# ---------------------------------------------------------------------------
elif page == "Lot deep-dive":
    st.markdown('<div class="section-title">Lot deep-dive</div>', unsafe_allow_html=True)

    lot_options = (
        inventory_base.sort_values("days_in_inventory", ascending=False)["lot_code"]
        .dropna()
        .unique()
        .tolist()
    )
    selected_lot = st.selectbox("Select lot", lot_options)
    lot_row = inventory_base[inventory_base["lot_code"] == selected_lot].iloc[0]

    # 3x2 Grid Layout for Lot deep-dive KPIs
    # Row 1
    r1_c1, r1_c2, r1_c3 = st.columns(3)
    r1_c1.metric("Flower", f"{lot_row['product_name']}")
    r1_c2.metric("Stems on hand", f"{int(lot_row['calculated_on_hand_stems']):,}")
    r1_c3.metric("Days since cut", f"{int(lot_row['days_since_cut']) if pd.notna(lot_row['days_since_cut']) else '—'}")

    st.write("") # Small spacer

    # Row 2
    r2_c1, r2_c2, r2_c3 = st.columns(3)
    r2_c1.metric("Days in warehouse", f"{int(lot_row['days_in_inventory']) if pd.notna(lot_row['days_in_inventory']) else '—'}")
    r2_c2.metric("Status", f"{STATUS_COLORS.get(lot_row['product_status'], '')} {lot_row['product_status']}")
    # r2_c3 is intentionally left empty for a clean 2x3 grid layout

    st.write(
        f"**Lot {selected_lot}** · SKU `{lot_row['sku']}` · {lot_row['variety'] or '—'} / {lot_row['color'] or '—'} · "
        f"Origin {lot_row['origin_country']} · Supplier {lot_row['supplier_name'] or '—'} · "
        f"Warehouse {lot_row['warehouse_name']} · Quality {lot_row['quality_status']} · Cut date {lot_row['cut_date'].date() if pd.notna(lot_row['cut_date']) else 'unknown'} · Received {lot_row['received_date'].date() if pd.notna(lot_row['received_date']) else 'unknown'} · Typical life after cut (illustrative): {int(lot_row['typical_life_days_after_cut']) if pd.notna(lot_row['typical_life_days_after_cut']) else '—'} days"
    )

    lot_id = int(lot_row["lot_id"])

    tx = try_query(f"SELECT transaction_date, transaction_type, quantity_stems, from_warehouse_id, to_warehouse_id, reference_type, reference_id, reason FROM inventory_transactions WHERE lot_id = {lot_id} ORDER BY transaction_date")
    reservations = try_query(f"SELECT reservation_date, reserved_quantity_stems, released_quantity_stems, status, sales_order_item_id FROM inventory_reservations WHERE lot_id = {lot_id} ORDER BY reservation_date")
    inspections = try_query(f"SELECT inspection_date, grade_observed, condition_score, rejected_quantity_stems, temperature_c, notes FROM quality_inspections WHERE lot_id = {lot_id} ORDER BY inspection_date")
    waste = try_query(f"SELECT waste_date, quantity_stems, reason, estimated_cost_usd, notes FROM waste_records WHERE lot_id = {lot_id} ORDER BY waste_date")

    tabs = st.tabs(["Transactions", "Reservations", "Inspections", "Waste"])
    with tabs[0]:
        if tx.empty: st.info("No inventory transactions for this lot.")
        else: st.dataframe(tx, use_container_width=True, hide_index=True)
    with tabs[1]:
        if reservations.empty: st.info("No reservations for this lot.")
        else: st.dataframe(reservations, use_container_width=True, hide_index=True)
    with tabs[2]:
        if inspections.empty: st.info("No quality inspections for this lot.")
        else: st.dataframe(inspections, use_container_width=True, hide_index=True)
    with tabs[3]:
        if waste.empty: st.info("No waste records for this lot.")
        else: st.dataframe(waste, use_container_width=True, hide_index=True)


# ---------------------------------------------------------------------------
# PAGE: Pricing & margins
# ---------------------------------------------------------------------------
elif page == "Pricing & margins":
    st.markdown('<div class="section-title">Pricing & margin analysis</div>', unsafe_allow_html=True)

    sales = try_query("""
        SELECT p.product_id, p.sku, p.product_name, p.variety,
               SUM(ii.quantity) AS units_sold, SUM(ii.stems_sold) AS stems_sold, SUM(ii.line_total) AS revenue,
               SUM(ii.line_total) / NULLIF(SUM(ii.stems_sold), 0) AS avg_price_per_stem
        FROM sales_invoice_items ii
        JOIN products p ON p.product_id = ii.product_id
        JOIN sales_invoices i ON i.sales_invoice_id = ii.sales_invoice_id
        WHERE i.status NOT IN ('draft','void')
        GROUP BY p.product_id, p.sku, p.product_name, p.variety
    """)
    cost_by_product = try_query("""
        SELECT product_id, SUM(initial_quantity_stems * unit_cost_usd) / NULLIF(SUM(initial_quantity_stems),0) AS avg_cost_per_stem
        FROM inventory_lots GROUP BY product_id
    """)

    if sales.empty:
        st.info("No posted sales found.")
    else:
        margins = sales.merge(cost_by_product, on="product_id", how="left")
        margins["avg_cost_per_stem"] = pd.to_numeric(margins["avg_cost_per_stem"], errors="coerce").fillna(0)
        margins["avg_price_per_stem"] = pd.to_numeric(margins["avg_price_per_stem"], errors="coerce").fillna(0)
        margins["gross_margin_usd"] = (margins["avg_price_per_stem"] - margins["avg_cost_per_stem"]) * margins["stems_sold"]
        margins["gross_margin_pct"] = np.where(margins["avg_price_per_stem"] > 0, (margins["avg_price_per_stem"] - margins["avg_cost_per_stem"]) / margins["avg_price_per_stem"], np.nan)

        total_rev = float(margins["revenue"].sum())
        total_gm = float(margins["gross_margin_usd"].sum())
        c1, c2, c3, c4 = st.columns(4)
        c1.metric("Revenue (posted)", money(total_rev))
        c2.metric("Gross margin est.", money(total_gm))
        c3.metric("Blended margin %", f"{(total_gm / total_rev * 100) if total_rev else 0:.1f}%")
        c4.metric("Products with sales", f"{margins['product_id'].nunique():,}")

        st.divider()
        st.markdown('<div class="section-title">Top products by margin</div>', unsafe_allow_html=True)
        top = margins.sort_values("gross_margin_usd", ascending=False).head(15).copy()
        top["gross_margin_pct"] = (top["gross_margin_pct"] * 100).round(1)
        display = top[["product_name", "variety", "stems_sold", "revenue", "avg_price_per_stem", "avg_cost_per_stem", "gross_margin_usd", "gross_margin_pct"]].rename(columns={
            "product_name": "Flower", "variety": "Variety", "stems_sold": "Stems sold", "revenue": "Revenue",
            "avg_price_per_stem": "Avg price / stem", "avg_cost_per_stem": "Avg cost / stem",
            "gross_margin_usd": "Gross margin $", "gross_margin_pct": "Gross margin %",
        })
        for col in ["Revenue", "Avg price / stem", "Avg cost / stem", "Gross margin $"]:
            display[col] = display[col].round(2)
        st.dataframe(display, use_container_width=True, hide_index=True)
        render_csv(display, "florai_margins.csv", key="margins_csv")

        st.divider()
        st.markdown('<div class="section-title">Price list</div>', unsafe_allow_html=True)
        prices = try_query("""
            SELECT p.product_name, p.variety, pp.customer_type, pp.uom_code, pp.currency_code, pp.price, pp.valid_from, pp.valid_to
            FROM product_prices pp JOIN products p ON p.product_id = pp.product_id
            ORDER BY p.product_name, pp.customer_type, pp.valid_from DESC
        """)
        if prices.empty: st.info("No product prices configured.")
        else: st.dataframe(prices, use_container_width=True, hide_index=True)


# ---------------------------------------------------------------------------
# PAGE: Sales analytics
# ---------------------------------------------------------------------------
elif page == "Sales analytics":
    st.markdown('<div class="section-title">Sales analytics</div>', unsafe_allow_html=True)

    monthly = try_query("SELECT * FROM v_monthly_sales ORDER BY sales_month")
    by_product = try_query("SELECT * FROM v_sales_by_product ORDER BY sales_revenue DESC")

    if monthly.empty and by_product.empty:
        st.info("No sales data available.")
    else:
        c1, c2, c3 = st.columns(3)
        if not monthly.empty:
            total_invoiced = float(pd.to_numeric(monthly["invoiced_amount"], errors="coerce").sum())
            c1.metric("Total invoiced", money(total_invoiced))
            c2.metric("Invoices", f"{int(pd.to_numeric(monthly['invoice_count'], errors='coerce').sum()):,}")
            c3.metric("Months with activity", f"{len(monthly)}")

        if not monthly.empty:
            st.markdown('<div class="section-title">Monthly invoiced amount</div>', unsafe_allow_html=True)
            st.bar_chart(monthly.set_index("sales_month")[["invoiced_amount"]], color="#5CB37B")

        st.divider()
        st.markdown('<div class="section-title">Top products by revenue</div>', unsafe_allow_html=True)
        if not by_product.empty:
            top = by_product.head(15).copy()
            for col in ["units_sold", "stems_sold", "sales_revenue"]:
                top[col] = pd.to_numeric(top[col], errors="coerce").fillna(0)
            st.bar_chart(top.set_index("product_name")[["sales_revenue"]], horizontal=True, color="#5CB37B")
            st.dataframe(top, use_container_width=True, hide_index=True)
            render_csv(top, "florai_sales_by_product.csv", key="sales_by_product_csv")

        st.divider()
        st.markdown('<div class="section-title">Channel breakdown</div>', unsafe_allow_html=True)
        channels = try_query("""
            SELECT sales_channel, COUNT(*) AS order_count,
                   SUM(CASE WHEN status IN ('confirmed','partially_fulfilled','fulfilled') THEN 1 ELSE 0 END) AS confirmed_orders
            FROM sales_orders GROUP BY sales_channel ORDER BY order_count DESC
        """)
        if channels.empty: st.info("No sales orders found.")
        else: st.dataframe(channels, use_container_width=True, hide_index=True)

        st.divider()
        st.markdown('<div class="section-title">Top customers</div>', unsafe_allow_html=True)
        top_customers = try_query("""
            SELECT c.customer_name, c.customer_type, c.country_code, COUNT(i.sales_invoice_id) AS invoice_count, SUM(i.total_amount) AS invoiced_total
            FROM sales_invoices i JOIN customers c ON c.customer_id = i.customer_id
            WHERE i.status NOT IN ('draft','void')
            GROUP BY c.customer_id, c.customer_name, c.customer_type, c.country_code
            ORDER BY invoiced_total DESC LIMIT 15
        """)
        if top_customers.empty: st.info("No customer invoices found.")
        else: st.dataframe(top_customers, use_container_width=True, hide_index=True)


# ---------------------------------------------------------------------------
# PAGE: Waste & quality
# ---------------------------------------------------------------------------
elif page == "Waste & quality":
    st.markdown('<div class="section-title">Waste & quality</div>', unsafe_allow_html=True)

    waste = try_query("SELECT * FROM v_waste_by_product ORDER BY wasted_stems DESC")
    total_waste_cost = try_query("SELECT COALESCE(SUM(estimated_cost_usd), 0) AS total_cost, COALESCE(SUM(quantity_stems), 0) AS total_stems FROM waste_records")

    c1, c2 = st.columns(2)
    if not total_waste_cost.empty:
        c1.metric("Wasted stems", f"{int(num(total_waste_cost.loc[0, 'total_stems'])):,}")
        c2.metric("Estimated waste cost", money(num(total_waste_cost.loc[0, 'total_cost'])))

    if waste.empty:
        st.info("No waste records found.")
    else:
        waste["wasted_stems"] = pd.to_numeric(waste["wasted_stems"], errors="coerce").fillna(0)
        waste["estimated_waste_cost_usd"] = pd.to_numeric(waste["estimated_waste_cost_usd"], errors="coerce").fillna(0)

        st.markdown('<div class="section-title">Waste Pareto (top 15 products)</div>', unsafe_allow_html=True)
        pareto = waste.head(15).copy()
        pareto["cumulative_pct"] = (pareto["wasted_stems"].cumsum() / pareto["wasted_stems"].sum() * 100).round(1)
        st.bar_chart(pareto.set_index("product_name")[["wasted_stems"]], color="#E05A47")
        st.dataframe(pareto, use_container_width=True, hide_index=True)

        st.divider()
        st.markdown('<div class="section-title">Waste by reason</div>', unsafe_allow_html=True)
        reasons = try_query("""
            SELECT reason, COUNT(*) AS records, SUM(quantity_stems) AS stems, SUM(estimated_cost_usd) AS estimated_cost
            FROM waste_records GROUP BY reason ORDER BY stems DESC
        """)
        if not reasons.empty: st.dataframe(reasons, use_container_width=True, hide_index=True)

        st.divider()
        st.markdown('<div class="section-title">Open quality claims</div>', unsafe_allow_html=True)
        claims = try_query("""
            SELECT qc.claim_date, s.supplier_name, qc.claim_type, qc.claimed_amount, qc.currency_code, qc.status, qc.resolution_notes
            FROM quality_claims qc LEFT JOIN suppliers s ON s.supplier_id = qc.supplier_id
            WHERE qc.status NOT IN ('settled','rejected') ORDER BY qc.claim_date DESC
        """)
        if claims.empty: st.info("No open quality claims.")
        else: st.dataframe(claims, use_container_width=True, hide_index=True)


# ---------------------------------------------------------------------------
# PAGE: Supplier & purchasing
# ---------------------------------------------------------------------------
elif page == "Supplier & purchasing":
    st.markdown('<div class="section-title">Supplier & purchasing</div>', unsafe_allow_html=True)

    spend = try_query("SELECT * FROM v_supplier_spend ORDER BY invoiced_amount DESC")
    if spend.empty:
        st.info("No supplier invoices found.")
    else:
        c1, c2, c3 = st.columns(3)
        c1.metric("Suppliers with invoices", f"{int((pd.to_numeric(spend['invoiced_amount'], errors='coerce').fillna(0) > 0).sum()):,}")
        c2.metric("Total invoiced (all currencies)", f"{float(pd.to_numeric(spend['invoiced_amount'], errors='coerce').fillna(0).sum()):,.0f}")
        c3.metric("Invoices", f"{int(pd.to_numeric(spend['invoice_count'], errors='coerce').fillna(0).sum()):,}")
        st.markdown('<div class="section-title">Supplier spend</div>', unsafe_allow_html=True)
        st.dataframe(spend, use_container_width=True, hide_index=True)

    st.divider()
    st.markdown('<div class="section-title">Open purchase orders</div>', unsafe_allow_html=True)
    open_pos = try_query("""
        SELECT po.po_number, s.supplier_name, po.order_date, po.expected_delivery_date, po.currency_code, po.status
        FROM purchase_orders po JOIN suppliers s ON s.supplier_id = po.supplier_id
        WHERE po.status NOT IN ('received','cancelled','closed') ORDER BY po.expected_delivery_date NULLS LAST
    """)
    if open_pos.empty: st.info("No open purchase orders.")
    else: st.dataframe(open_pos, use_container_width=True, hide_index=True)

    st.divider()
    st.markdown('<div class="section-title">Shipments in transit / expected</div>', unsafe_allow_html=True)
    shipments = try_query("""
        SELECT shipment_reference, origin_country_code, origin_airport_or_port, destination_airport_or_port,
               departure_date, expected_arrival_date, actual_arrival_date, status
        FROM shipments WHERE status IN ('planned','in_transit','delayed') ORDER BY expected_arrival_date NULLS LAST
    """)
    if shipments.empty: st.info("No shipments pending.")
    else: st.dataframe(shipments, use_container_width=True, hide_index=True)

    st.divider()
    st.markdown('<div class="section-title">Freight & landed cost charges</div>', unsafe_allow_html=True)
    freight = try_query("""
        SELECT fc.charge_date, sh.shipment_reference, fc.charge_type, fc.amount, fc.currency_code, fc.allocation_basis, fc.description
        FROM freight_charges fc JOIN shipments sh ON sh.shipment_id = fc.shipment_id
        ORDER BY fc.charge_date DESC LIMIT 50
    """)
    if freight.empty: st.info("No freight charges recorded.")
    else: st.dataframe(freight, use_container_width=True, hide_index=True)


# ---------------------------------------------------------------------------
# PAGE: AR / AP aging
# ---------------------------------------------------------------------------
elif page == "AR / AP aging":
    st.markdown('<div class="section-title">Accounts receivable & payable aging</div>', unsafe_allow_html=True)

    ar = try_query("SELECT * FROM v_accounts_receivable_aging")
    ap = try_query("SELECT * FROM v_accounts_payable_aging")

    tab_ar, tab_ap = st.tabs(["Accounts receivable", "Accounts payable"])

    with tab_ar:
        if ar.empty:
            st.info("No open receivables.")
        else:
            ar["outstanding_amount"] = pd.to_numeric(ar["outstanding_amount"], errors="coerce").fillna(0)
            ar["total_amount"] = pd.to_numeric(ar["total_amount"], errors="coerce").fillna(0)
            c1, c2, c3 = st.columns(3)
            c1.metric("Total invoiced", money(ar["total_amount"].sum()))
            c2.metric("Outstanding", money(ar["outstanding_amount"].sum()))
            c3.metric("Open invoices", f"{len(ar):,}")

            st.markdown('<div class="section-title">Aging buckets</div>', unsafe_allow_html=True)
            buckets = ar.groupby("aging_bucket", as_index=False)["outstanding_amount"].sum().sort_values("outstanding_amount", ascending=False)
            st.bar_chart(buckets.set_index("aging_bucket")[["outstanding_amount"]], color="#5CB37B")
            st.dataframe(buckets.round(2), use_container_width=True, hide_index=True)

            st.markdown('<div class="section-title">Invoice detail</div>', unsafe_allow_html=True)
            st.dataframe(ar.sort_values("outstanding_amount", ascending=False), use_container_width=True, hide_index=True)

    with tab_ap:
        if ap.empty:
            st.info("No open payables.")
        else:
            ap["outstanding_amount"] = pd.to_numeric(ap["outstanding_amount"], errors="coerce").fillna(0)
            ap["total_amount"] = pd.to_numeric(ap["total_amount"], errors="coerce").fillna(0)
            c1, c2, c3 = st.columns(3)
            c1.metric("Total invoiced", money(ap["total_amount"].sum()))
            c2.metric("Outstanding", money(ap["outstanding_amount"].sum()))
            c3.metric("Open invoices", f"{len(ap):,}")

            st.markdown('<div class="section-title">Aging buckets</div>', unsafe_allow_html=True)
            buckets = ap.groupby("aging_bucket", as_index=False)["outstanding_amount"].sum().sort_values("outstanding_amount", ascending=False)
            st.bar_chart(buckets.set_index("aging_bucket")[["outstanding_amount"]], color="#E05A47")
            st.dataframe(buckets.round(2), use_container_width=True, hide_index=True)

            st.markdown('<div class="section-title">Invoice detail</div>', unsafe_allow_html=True)
            st.dataframe(ap.sort_values("outstanding_amount", ascending=False), use_container_width=True, hide_index=True)


# ---------------------------------------------------------------------------
# Footer
# ---------------------------------------------------------------------------
st.divider()
st.caption(
    "Demo data is synthetic. Aging thresholds are configurable decision-support rules and do not "
    "replace physical flower inspection. This dashboard is read-only and does not write to the database."
)