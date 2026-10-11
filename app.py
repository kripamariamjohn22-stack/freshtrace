# =====================================================================
# FreshTrace : Food Batch Traceability & Recall System (website v3)
# Run:  python -m streamlit run app.py
# The website stores NO data itself. Every page runs SQL queries and
# views on the MySQL database "freshtrace" built in MySQL Workbench.
# =====================================================================
import streamlit as st
import pandas as pd
import mysql.connector
from datetime import date

# ---------- 1. DATABASE CONNECTION (put your password here) ----------
DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": "YOUR_MYSQL_PASSWORD",   # <-- your MySQL root password, inside the quotes
    "database": "freshtrace",
}

# When the app runs online (Streamlit Community Cloud), the connection details
# come from the hosting site's "Secrets" box instead of this file, so the
# password is never uploaded to GitHub.
try:
    DB_CONFIG = {k: (int(v) if k == "port" else v) for k, v in st.secrets["mysql"].items()}
except Exception:
    pass   # no secrets found -> running on your laptop -> use DB_CONFIG above

def get_conn():
    return mysql.connector.connect(**DB_CONFIG)

def run_query(sql, params=None):
    """Run a SELECT and return the result as a table (DataFrame)."""
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(sql, params or ())
        cols = [c[0] for c in cur.description]
        return pd.DataFrame(cur.fetchall(), columns=cols)
    finally:
        conn.close()

def run_change(sql, params):
    """Run one INSERT/UPDATE inside a transaction (COMMIT or ROLLBACK)."""
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(sql, params)
        conn.commit()
        return cur.rowcount
    except mysql.connector.Error:
        conn.rollback()
        raise
    finally:
        conn.close()

def run_transaction(steps):
    """Run several statements as ONE transaction: all succeed (COMMIT) or none (ROLLBACK)."""
    conn = get_conn()
    try:
        cur = conn.cursor()
        for sql, params in steps:
            cur.execute(sql, params)
        conn.commit()
    except mysql.connector.Error:
        conn.rollback()
        raise
    finally:
        conn.close()

# ---------- 2. LOOK AND FEEL ----------
# Palette: ledger indigo, cool paper, kraft-paper labels, one turmeric accent.
INK, PAPER, KRAFT, TURMERIC = "#1E2A3E", "#F5F6F3", "#E9DCC2", "#D9A21B"
SAFE, RECALL, HOLD = "#2E7D50", "#B3261E", "#A15C00"

st.set_page_config(page_title="FreshTrace", page_icon="🌶️", layout="wide")
try:   # use our colours for Streamlit's own widgets (progress bar, tabs, sliders)
    st._config.set_option("theme.primaryColor", TURMERIC)
except Exception:
    pass

st.markdown(f"""
<style>
@import url('https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,500;12..96,700&family=Source+Sans+3:wght@400;600&family=DotGothic16&display=swap');

html, body, [class*="css"], .stMarkdown, .stText, p, li, label, input, textarea {{
    font-family: 'Source Sans 3', system-ui, sans-serif;
}}
.stApp {{ background: {PAPER}; color: {INK}; }}
h1, h2, h3 {{ font-family: 'Bricolage Grotesque', 'Source Sans 3', sans-serif !important;
             color: {INK} !important; letter-spacing: -0.01em; }}
h1 {{ font-size: 2.6rem !important; font-weight: 700 !important; }}
h2, h3 {{ font-weight: 600 !important; }}
[data-testid="stHeaderActionElements"] {{ display: none; }}
[data-testid="stHeader"] {{ background: transparent; }}   /* hide link icons next to titles */
.block-container {{ padding-top: 2.2rem; max-width: 1150px; }}

/* ---- sidebar: the ledger cover ---- */
[data-testid="stSidebar"] {{ background: {INK}; }}
[data-testid="stSidebar"] * {{ color: #E6E9EF; }}
[data-testid="stSidebar"] .brand {{ font-family: 'Bricolage Grotesque', sans-serif; font-size: 1.9rem;
    font-weight: 700; color: #FFFFFF; margin: 0.4rem 0 0.1rem 0; }}
[data-testid="stSidebar"] .tagline {{ font-size: 0.92rem; color: #AEB6C4; margin-bottom: 1.4rem; }}
[data-testid="stSidebar"] .group {{ font-size: 0.85rem; color: #8C96A8; margin: 1.1rem 0 0.3rem 0.2rem; }}
[data-testid="stSidebar"] button {{
    justify-content: flex-start !important; border: none !important; border-radius: 6px !important;
    background: transparent !important; box-shadow: none !important; padding-left: 0.8rem !important; }}
[data-testid="stSidebar"] button > div, [data-testid="stSidebar"] button [data-testid="stMarkdownContainer"] {{
    justify-content: flex-start !important; text-align: left !important; width: 100%; }}
[data-testid="stSidebar"] button p {{ font-size: 1rem; color: #D5DAE3 !important; text-align: left !important; }}
[data-testid="stSidebar"] button:hover {{ background: rgba(255,255,255,0.06) !important; }}
[data-testid="stSidebar"] button[kind="primary"],
[data-testid="stSidebar"] [data-testid="stBaseButton-primary"] {{
    background: rgba(255,255,255,0.09) !important; border-left: 3px solid {TURMERIC} !important;
    border-radius: 0 6px 6px 0 !important; }}
[data-testid="stSidebar"] button[kind="primary"] p,
[data-testid="stSidebar"] [data-testid="stBaseButton-primary"] p {{ color: #FFFFFF !important; font-weight: 600; }}
[data-testid="stSidebar"] .foot {{ font-size: 0.8rem; color: #8C96A8; margin-top: 2rem; line-height: 1.45; }}

/* ---- main-area buttons ---- */
.main [data-testid="stBaseButton-primary"], section.main button[kind="primary"] {{
    background: {INK} !important; border-color: {INK} !important; }}
[data-testid="stMain"] [data-testid="stBaseButton-primary"] {{ background: {INK} !important; border-color: {INK} !important; color: #fff !important; }}
[data-testid="stMain"] [data-testid="stBaseButton-secondary"] {{ border-color: #C9CDD4 !important; color: {INK} !important; background: #fff !important; }}

/* ---- metrics: ledger figures ---- */
[data-testid="stMetric"] {{ background: #FFFFFF; border: 1px solid #DDE0E5; border-left: 4px solid {INK};
    border-radius: 4px; padding: 0.8rem 1rem; }}
[data-testid="stMetricValue"] {{ font-family: 'Bricolage Grotesque', sans-serif; color: {INK}; }}
[data-testid="stMetricLabel"] p {{ color: #5B6474; }}

.lede {{ font-size: 1.08rem; color: #475063; max-width: 62ch; margin: -0.4rem 0 1.6rem 0; line-height: 1.5; }}

/* ---- the packet label (Check a Product) ---- */
.label {{ position: relative; background: {KRAFT}; color: #2B2418; border-radius: 3px; padding: 1.6rem 1.8rem 1.4rem;
    max-width: 640px; margin: 0.6rem 0 1.2rem 0; border-top: 2px dashed #B9A57E; border-bottom: 2px dashed #B9A57E; }}
.label .product {{ font-family: 'Bricolage Grotesque', sans-serif; font-size: 1.55rem; font-weight: 700; margin: 0; }}
.label .row {{ display: flex; gap: 2.2rem; margin-top: 1rem; flex-wrap: wrap; }}
.label .k {{ font-size: 0.82rem; color: #6E5F44; }}
.label .v {{ font-family: 'DotGothic16', monospace; font-size: 1.25rem; letter-spacing: 0.06em; }}
.label .code {{ font-family: 'DotGothic16', monospace; font-size: 2.1rem; letter-spacing: 0.08em; margin-top: 0.2rem; }}
.stamp {{ position: absolute; right: 1.6rem; top: 1.3rem; transform: rotate(-8deg);
    font-family: 'Bricolage Grotesque', sans-serif; font-weight: 700; font-size: 1.5rem; letter-spacing: 0.08em;
    padding: 0.25rem 0.8rem; border: 3px double currentColor; border-radius: 6px; opacity: 0.9; }}
.advice {{ max-width: 640px; border-left: 4px solid; padding: 0.9rem 1.1rem; background: #FFFFFF; border-radius: 0 4px 4px 0;
    line-height: 1.5; }}
.advice b {{ font-family: 'Bricolage Grotesque', sans-serif; }}
@media (max-width: 640px) {{ .stamp {{ position: static; display: inline-block; margin-bottom: 0.8rem; }} }}
</style>
""", unsafe_allow_html=True)

def page_header(title, lede):
    st.title(title)
    st.markdown(f'<p class="lede">{lede}</p>', unsafe_allow_html=True)

# ---------- 3. NAVIGATION (sidebar) ----------
PAGES = {
    "For shops and customers": ["Check a product"],
    "For the factory": ["Recall desk", "Overview", "Trace a lot", "Supplier risk", "Expiry alerts", "Record a shipment"],
}
if "page" not in st.session_state:
    st.session_state.page = "Check a product"

with st.sidebar:
    st.markdown('<div class="brand">FreshTrace</div>'
                '<div class="tagline">Know where every spice lot went, and get it back fast when it is unsafe.</div>',
                unsafe_allow_html=True)
    for group, items in PAGES.items():
        st.markdown(f'<div class="group">{group}</div>', unsafe_allow_html=True)
        for name in items:
            st.button(name, key=f"nav_{name}", width="stretch",
                      type="primary" if st.session_state.page == name else "secondary",
                      on_click=lambda n=name: st.session_state.update(page=n))
    st.markdown('<div class="foot">Sample data with fictional companies.<br>Runs on the MySQL database <i>freshtrace</i>.</div>',
                unsafe_allow_html=True)
page = st.session_state.page

try:
    get_conn().close()
except mysql.connector.Error as e:
    st.error(f"Cannot connect to MySQL: {e}")
    st.info("Check that MySQL is running, the password in DB_CONFIG is correct, and the database 'freshtrace' exists.")
    st.stop()

# =====================================================================
# CHECK A PRODUCT  (shopkeepers and customers)
# =====================================================================
if page == "Check a product":
    page_header("Check a product",
                "Type the batch code printed on the packet. You will see at once whether it is safe to sell and eat.")

    examples = {"B-HLD-2607-01": "Haldi, recalled", "B-MTH-2607-01": "Mathri, expired",
                "B-GRM-2608-01": "Garam masala, safe", "B-MRC-2608-01": "Lal mirch, on hold"}
    code = st.text_input("Batch code", key="code", placeholder="for example  B-HLD-2607-01").strip().upper()
    st.caption("Or try a sample packet:")
    cols = st.columns(len(examples))
    for col, (ex, desc) in zip(cols, examples.items()):
        col.button(desc, key=f"ex_{ex}", width="stretch",
                   on_click=lambda v=ex: st.session_state.update(code=v))

    if code:
        info = run_query("""
            SELECT b.batch_code, p.product_name, b.batch_status, b.mfg_date,
                   DATE_ADD(b.mfg_date, INTERVAL p.shelf_life_days DAY)                     AS expiry_date,
                   DATEDIFF(DATE_ADD(b.mfg_date, INTERVAL p.shelf_life_days DAY), CURDATE()) AS days_left
            FROM production_batch b
            JOIN product p ON p.product_id = b.product_id
            WHERE b.batch_code = %s
        """, (code,))

        if info.empty:
            st.warning(f"No batch called {code}. Check the code on the packet; it starts with B- and has two numbers after the product letters.")
        else:
            b = info.iloc[0]
            rec = run_query("""
                SELECT rc.recall_status, rc.severity, rc.reason, rc.recall_date
                FROM production_batch pb
                JOIN batch_ingredient bi ON bi.batch_id = pb.batch_id
                JOIN recall rc           ON rc.lot_id   = bi.lot_id
                WHERE pb.batch_code = %s
                ORDER BY rc.recall_status = 'OPEN' DESC
            """, (code,))

            if not rec.empty and rec.iloc[0].recall_status == "OPEN":
                r = rec.iloc[0]
                verdict, colour = "RECALLED", RECALL
                advice = (f"<b>Do not sell or eat this product.</b> It was recalled on {r.recall_date:%d %b %Y} "
                          f"({r.severity.lower()} severity). Reason: {r.reason}.<br>"
                          "Shops: take it off the shelf and keep it aside for collection. "
                          "Customers: return it to the shop where you bought it.")
            elif b.batch_status == "RECALLED":
                verdict, colour = "RECALLED", RECALL
                advice = "<b>This batch was recalled earlier.</b> It should not be on any shelf. Return it to the supplier."
            elif b.batch_status in ("ON_HOLD", "IN_QC"):
                verdict, colour = "ON HOLD", HOLD
                advice = ("<b>Not released for sale.</b> This batch is still in quality control or failed a check. "
                          "If it is on your shelf, contact the supplier.")
            elif b.days_left < 0:
                verdict, colour = "EXPIRED", HOLD
                advice = f"<b>Expired {abs(int(b.days_left))} days ago.</b> Do not sell or eat it. Remove it from the shelf."
            else:
                verdict, colour = "SAFE", SAFE
                advice = (f"<b>Safe to sell and eat.</b> Released after quality checks, not under any recall, "
                          f"and {int(b.days_left)} days left before the best-before date.")

            st.markdown(f"""
            <div class="label">
              <div class="stamp" style="color:{colour}">{verdict}</div>
              <p class="product">{b.product_name}</p>
              <div class="code">{b.batch_code}</div>
              <div class="row">
                <div><div class="k">Made on</div><div class="v">{b.mfg_date:%d %b %Y}</div></div>
                <div><div class="k">Best before</div><div class="v">{b.expiry_date:%d %b %Y}</div></div>
              </div>
            </div>
            <div class="advice" style="border-color:{colour}">{advice}</div>
            """, unsafe_allow_html=True)

# =====================================================================
# RECALL DESK  (factory quality team)
# =====================================================================
elif page == "Recall desk":
    page_header("Recall desk",
                "Raise a recall when a lot fails a test, call every shop that received it, and close the recall only when every unit is back.")
    tab_track, tab_raise = st.tabs(["Track a recall", "Raise a new recall"])

    with tab_track:
        prog = run_query("SELECT * FROM v_recall_progress ORDER BY recall_status = 'OPEN' DESC, recall_id DESC")
        if prog.empty:
            st.info("No recalls yet. Use the 'Raise a new recall' tab when a lot fails a test.")
        else:
            pick = st.selectbox("Recall", prog.itertuples(),
                                format_func=lambda r: f"Recall #{r.recall_id}, lot {r.lot_code} ({r.recall_status.lower()})")
            c1, c2, c3 = st.columns(3)
            c1.metric("Shops finished", f"{int(pick.shops_done)} of {int(pick.shops)}")
            c2.metric("Units recovered", f"{int(pick.units_returned):,} of {int(pick.units_to_return):,}")
            c3.metric("Recovered", f"{float(pick.percent_recovered):.0f}%")
            st.progress(min(float(pick.percent_recovered) / 100, 1.0))

            notices = run_query("""
                SELECT r.retailer_id, r.retailer_name AS shop, r.city, r.phone,
                       n.units_to_return, n.notified_on, n.units_returned, n.notice_status AS status
                FROM recall_notice n
                JOIN retailer r ON r.retailer_id = n.retailer_id
                WHERE n.recall_id = %s
                ORDER BY n.notice_status, r.retailer_name
            """, (int(pick.recall_id),))

            st.download_button("Download call list (CSV)",
                               notices[["shop", "city", "phone", "units_to_return", "status"]].to_csv(index=False),
                               file_name=f"recall_{int(pick.recall_id)}_call_list.csv", mime="text/csv")

            if pick.recall_status == "OPEN":
                st.subheader("Shops to contact")
                edited = st.data_editor(
                    notices, hide_index=True, key=f"ed_{int(pick.recall_id)}",
                    disabled=["retailer_id", "shop", "city", "phone", "units_to_return", "notified_on"],
                    column_config={
                        "retailer_id": None,
                        "status": st.column_config.SelectboxColumn("status", options=["PENDING", "CONTACTED", "COLLECTED"]),
                        "units_returned": st.column_config.NumberColumn("units_returned", min_value=0, step=10),
                    })
                left, right = st.columns([1, 1])
                if left.button("Save progress", type="primary", width="stretch"):
                    steps = []
                    for row in edited.itertuples():
                        units = int(row.units_to_return) if row.status == "COLLECTED" else int(row.units_returned)
                        steps.append(("""UPDATE recall_notice
                                         SET notice_status = %s, units_returned = %s,
                                             notified_on = CASE WHEN %s = 'PENDING' THEN NULL
                                                                ELSE COALESCE(notified_on, CURDATE()) END
                                         WHERE recall_id = %s AND retailer_id = %s""",
                                      (row.status, units, row.status, int(pick.recall_id), int(row.retailer_id))))
                    try:
                        run_transaction(steps)
                        st.rerun()
                    except mysql.connector.Error as e:
                        st.error(f"Not saved. The database rejected it: {e.msg}")
                all_done = int(pick.shops_done) == int(pick.shops)
                if right.button("Close recall", width="stretch", disabled=not all_done):
                    run_change("UPDATE recall SET recall_status = 'CLOSED' WHERE recall_id = %s", (int(pick.recall_id),))
                    st.rerun()
                if not all_done:
                    st.caption(f"You can close this recall once all {int(pick.shops)} shops are marked COLLECTED.")
            else:
                st.dataframe(notices.drop(columns=["retailer_id"]), hide_index=True)

    with tab_raise:
        st.write("When a lab test shows a raw-material lot is unsafe, raise a recall here. In one transaction FreshTrace "
                 "creates the recall, marks the lot and every batch made from it as recalled, and adds every shop "
                 "that received those batches to the call list.")
        candidates = run_query("""
            SELECT l.lot_id, l.lot_code, m.material_name, s.supplier_name
            FROM material_lot l
            JOIN raw_material m ON m.material_id = l.material_id
            JOIN supplier s     ON s.supplier_id = l.supplier_id
            WHERE l.lot_id NOT IN (SELECT lot_id FROM recall)
              AND l.lot_id IN (SELECT lot_id FROM batch_ingredient)
            ORDER BY l.lot_code
        """)
        with st.form("raise"):
            lot = st.selectbox("Unsafe lot", candidates.itertuples(),
                               format_func=lambda r: f"{r.lot_code}, {r.material_name} from {r.supplier_name}")
            reason = st.text_input("Reason", "Lab test failed")
            severity = st.selectbox("Severity", ["HIGH", "MEDIUM", "LOW"])
            preview = st.form_submit_button("Preview impact")
        if preview or st.session_state.get("raise_lot") == int(lot.lot_id):
            st.session_state["raise_lot"] = int(lot.lot_id)
            impact = run_query("""
                SELECT r.retailer_name AS shop, r.city, SUM(sh.units_shipped) AS units
                FROM batch_ingredient bi
                JOIN shipment sh ON sh.batch_id   = bi.batch_id
                JOIN retailer r  ON r.retailer_id = sh.retailer_id
                WHERE bi.lot_id = %s
                GROUP BY r.retailer_id, r.retailer_name, r.city
            """, (int(lot.lot_id),))
            total = int(impact.units.sum()) if not impact.empty else 0
            st.markdown(f"**{len(impact)} shops** will be added to the call list, with **{total:,} units** to recover.")
            st.dataframe(impact, hide_index=True)
            if st.button("Raise recall", type="primary"):
                lid = int(lot.lot_id)
                steps = [
                    ("INSERT INTO recall (lot_id, recall_date, reason, severity) VALUES (%s, CURDATE(), %s, %s)",
                     (lid, reason, severity)),
                    ("UPDATE material_lot SET lot_status = 'RECALLED' WHERE lot_id = %s", (lid,)),
                    ("""UPDATE production_batch SET batch_status = 'RECALLED'
                        WHERE batch_id IN (SELECT batch_id FROM batch_ingredient WHERE lot_id = %s)""", (lid,)),
                    ("""INSERT INTO recall_notice (recall_id, retailer_id, units_to_return)
                        SELECT rc.recall_id, sh.retailer_id, SUM(sh.units_shipped)
                        FROM recall rc
                        JOIN batch_ingredient bi ON bi.lot_id   = rc.lot_id
                        JOIN shipment sh         ON sh.batch_id = bi.batch_id
                        WHERE rc.lot_id = %s
                        GROUP BY rc.recall_id, sh.retailer_id""", (lid,)),
                ]
                try:
                    run_transaction(steps)
                    st.session_state.pop("raise_lot", None)
                    st.success("Recall raised. Open 'Track a recall' to start calling shops.")
                except mysql.connector.Error as e:
                    st.error(f"Nothing was saved (rolled back). The database said: {e.msg}")

# =====================================================================
# OVERVIEW
# =====================================================================
elif page == "Overview":
    page_header("Overview", "Every lot, batch and shipment in one place, from the farm gate to the shop shelf.")
    c = run_query("""
        SELECT (SELECT COUNT(*) FROM supplier)                          AS suppliers,
               (SELECT COUNT(*) FROM material_lot)                      AS lots,
               (SELECT COUNT(*) FROM production_batch)                  AS batches,
               (SELECT COUNT(*) FROM shipment)                          AS shipments,
               (SELECT COUNT(*) FROM recall WHERE recall_status='OPEN') AS open_recalls
    """).iloc[0]
    m = st.columns(5)
    m[0].metric("Suppliers", int(c.suppliers)); m[1].metric("Raw-material lots", int(c.lots))
    m[2].metric("Batches made", int(c.batches)); m[3].metric("Shipments", int(c.shipments))
    m[4].metric("Open recalls", int(c.open_recalls))

    st.subheader("Open recalls")
    st.dataframe(run_query("""
        SELECT rc.recall_id, l.lot_code, s.supplier_name, rc.recall_date, rc.severity, rc.reason
        FROM recall rc JOIN material_lot l ON l.lot_id = rc.lot_id JOIN supplier s ON s.supplier_id = l.supplier_id
        WHERE rc.recall_status = 'OPEN'"""), hide_index=True)

    st.subheader("Units produced per product")
    prod = run_query("""
        SELECT p.product_name, SUM(b.units_produced) AS units
        FROM product p JOIN production_batch b ON b.product_id = p.product_id
        GROUP BY p.product_id, p.product_name ORDER BY units DESC""")
    prod["units"] = prod["units"].astype(int)          # SUM() comes back as a decimal; charts need numbers
    st.bar_chart(prod.set_index("product_name"), color=INK, horizontal=True)

# =====================================================================
# TRACE A LOT  (the star query, for any lot)
# =====================================================================
elif page == "Trace a lot":
    page_header("Trace a lot", "Pick a raw-material lot and follow it through every batch to every shop that received it.")
    lots = run_query("""
        SELECT l.lot_code, m.material_name, s.supplier_name, l.lot_status
        FROM material_lot l
        JOIN raw_material m ON m.material_id = l.material_id
        JOIN supplier s     ON s.supplier_id = l.supplier_id
        ORDER BY (l.lot_id IN (SELECT lot_id FROM recall WHERE recall_status = 'OPEN')) DESC,
                 (l.lot_status = 'RECALLED') DESC, l.lot_code""")
    pick = st.selectbox("Lot", lots.itertuples(),
                        format_func=lambda r: f"{r.lot_code}, {r.material_name} from {r.supplier_name} ({r.lot_status.lower()})")
    trace = run_query("""
        SELECT b.batch_code, p.product_name, r.retailer_name AS shop, r.city, r.phone,
               sh.ship_date, sh.units_shipped
        FROM material_lot l
        JOIN batch_ingredient bi ON bi.lot_id     = l.lot_id
        JOIN production_batch b  ON b.batch_id    = bi.batch_id
        JOIN product          p  ON p.product_id  = b.product_id
        JOIN shipment         sh ON sh.batch_id   = b.batch_id
        JOIN retailer         r  ON r.retailer_id = sh.retailer_id
        WHERE l.lot_code = %s
        ORDER BY r.retailer_name""", (pick.lot_code,))
    if trace.empty:
        st.success("This lot has not reached any shop. It was never used, or its batches were not shipped.")
    else:
        c1, c2, c3 = st.columns(3)
        c1.metric("Batches made from it", trace.batch_code.nunique())
        c2.metric("Shops that received it", trace.shop.nunique())
        c3.metric("Units in the market", f"{int(trace.units_shipped.sum()):,}")
        st.dataframe(trace, hide_index=True)
    with st.expander("See the SQL behind this page"):
        st.code("""SELECT b.batch_code, p.product_name, r.retailer_name, r.city, r.phone, sh.ship_date, sh.units_shipped
FROM material_lot l
JOIN batch_ingredient bi ON bi.lot_id     = l.lot_id
JOIN production_batch b  ON b.batch_id    = bi.batch_id
JOIN product          p  ON p.product_id  = b.product_id
JOIN shipment         sh ON sh.batch_id   = b.batch_id
JOIN retailer         r  ON r.retailer_id = sh.retailer_id
WHERE l.lot_code = %s;""", language="sql")

# =====================================================================
# SUPPLIER RISK  (view v_supplier_scorecard)
# =====================================================================
elif page == "Supplier risk":
    page_header("Supplier risk", "How often each supplier's lots fail inspection. Use it to decide whom to buy from next.")
    sc = run_query("""SELECT supplier_name, city, lots_sent, total_tests, failed_tests, fail_percent, risk_band
                      FROM v_supplier_scorecard ORDER BY fail_percent DESC""")
    tint = {"HIGH RISK": "background-color:#F6DCDA", "WATCH": "background-color:#FBEBCF", "RELIABLE": "background-color:#DCEBE1"}
    st.dataframe(sc.style.map(lambda v: tint.get(v, ""), subset=["risk_band"]), hide_index=True)

    st.subheader("Failure rate, %")
    chart = sc.dropna(subset=["fail_percent"]).copy()
    chart["fail_percent"] = chart["fail_percent"].astype(float)
    st.bar_chart(chart.set_index("supplier_name")["fail_percent"], color=RECALL, horizontal=True)

    st.subheader("Backup suppliers for the same material")
    st.dataframe(run_query("""
        SELECT DISTINCT m.material_name, s1.supplier_name AS supplier_a, s2.supplier_name AS supplier_b
        FROM material_lot l1
        JOIN material_lot l2 ON l1.material_id = l2.material_id AND l1.supplier_id < l2.supplier_id
        JOIN supplier s1 ON s1.supplier_id = l1.supplier_id
        JOIN supplier s2 ON s2.supplier_id = l2.supplier_id
        JOIN raw_material m ON m.material_id = l1.material_id"""), hide_index=True)

# =====================================================================
# EXPIRY ALERTS  (views v_lot_expiry_alert, v_batch_shelf_status)
# =====================================================================
elif page == "Expiry alerts":
    page_header("Expiry alerts", "Stock that should be used, sold or pulled from shelves first.")
    days = st.slider("Show items expiring within this many days", 15, 180, 90)

    batches = run_query("""
        SELECT batch_code, product_name, batch_status, expiry_date, days_to_expiry, units_shipped, units_in_factory
        FROM v_batch_shelf_status WHERE days_to_expiry <= %s ORDER BY days_to_expiry""", (days,))
    expired = batches[batches.days_to_expiry < 0] if not batches.empty else batches
    if not expired.empty:
        st.error(f"{len(expired)} batch already past its best-before date: {', '.join(expired.batch_code)}. "
                 "Pull it from shops and stop dispatching it.")

    st.subheader("Finished products")
    if batches.empty:
        st.success("No batches expire in this window.")
    else:
        st.dataframe(batches, hide_index=True)

    st.subheader("Raw-material lots")
    lots = run_query("""
        SELECT lot_code, material_name, supplier_name, expiry_date, days_left, qty_left, alert
        FROM v_lot_expiry_alert WHERE days_left <= %s ORDER BY days_left""", (days,))
    if lots.empty:
        st.success("No lots expire in this window.")
    else:
        st.dataframe(lots, hide_index=True)

# =====================================================================
# RECORD A SHIPMENT  (INSERT; constraints enforced by MySQL)
# =====================================================================
elif page == "Record a shipment":
    page_header("Record a shipment",
                "Log a delivery to a shop. Only released batches can be shipped, and the database rejects impossible values.")
    batches = run_query("""
        SELECT b.batch_id, b.batch_code, p.product_name
        FROM production_batch b JOIN product p ON p.product_id = b.product_id
        WHERE b.batch_status = 'RELEASED' ORDER BY b.batch_code""")
    shops = run_query("SELECT retailer_id, retailer_name, city FROM retailer ORDER BY retailer_name")

    with st.form("ship_form"):
        c1, c2 = st.columns(2)
        b = c1.selectbox("Batch", batches.itertuples(), format_func=lambda r: f"{r.batch_code}, {r.product_name}")
        r = c2.selectbox("Shop", shops.itertuples(), format_func=lambda r: f"{r.retailer_name}, {r.city}")
        c3, c4 = st.columns(2)
        ship_date = c3.date_input("Ship date", value=date.today())
        units = c4.number_input("Units shipped", value=100, step=50)
        submitted = st.form_submit_button("Save shipment", type="primary")

    if submitted:
        try:
            run_change("""INSERT INTO shipment (batch_id, retailer_id, ship_date, units_shipped)
                          VALUES (%s, %s, %s, %s)""",
                       (int(b.batch_id), int(r.retailer_id), ship_date, int(units)))
            st.success(f"Shipment saved: {int(units)} units of {b.batch_code} to {r.retailer_name}.")
        except mysql.connector.Error as e:
            st.error(f"Not saved. The database rejected it: {e.msg}")
            st.caption("Units must be more than 0 (CHECK constraint chk_ship_units).")

    st.subheader("Latest shipments")
    st.dataframe(run_query("""
        SELECT s.shipment_id, b.batch_code, r.retailer_name AS shop, s.ship_date, s.units_shipped, s.delivery_status
        FROM shipment s JOIN production_batch b ON b.batch_id = s.batch_id JOIN retailer r ON r.retailer_id = s.retailer_id
        ORDER BY s.shipment_id DESC LIMIT 8"""), hide_index=True)
