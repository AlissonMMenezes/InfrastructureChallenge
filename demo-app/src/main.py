import html
import os
from typing import Any

import psycopg
from fastapi import FastAPI, Form
from fastapi.responses import HTMLResponse, RedirectResponse
from prometheus_fastapi_instrumentator import Instrumentator
from pydantic import BaseModel


DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "app")
DB_USER = os.getenv("DB_USER", "app")
DB_PASSWORD = os.getenv("DB_PASSWORD", "app")
# In-cluster: CloudNativePG Secret <cluster>-app key `uri` (wired as DATABASE_URL in the Deployment).
DATABASE_URL = os.getenv("DATABASE_URL")

app = FastAPI(title="demo-api", docs_url="/api/docs", openapi_url="/api/openapi.json")
Instrumentator().instrument(app).expose(app, endpoint="/metrics", include_in_schema=False)


class Item(BaseModel):
    name: str


def dsn() -> str:
    if DATABASE_URL:
        return DATABASE_URL
    return f"host={DB_HOST} port={DB_PORT} dbname={DB_NAME} user={DB_USER} password={DB_PASSWORD}"


@app.on_event("startup")
def startup() -> None:
    with psycopg.connect(dsn()) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS items (
                    id SERIAL PRIMARY KEY,
                    name TEXT NOT NULL
                )
                """
            )


def _page(title: str, inner: str) -> str:
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>{html.escape(title)}</title>
  <style>
    :root {{
      --bg: #0f1419;
      --panel: #1a2332;
      --text: #e7ecf3;
      --muted: #8b9cb3;
      --accent: #f59e0b;
      --ok: #34d399;
      --bad: #f87171;
      --border: #2d3a4f;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      font-family: "Segoe UI", system-ui, sans-serif;
      background: var(--bg);
      color: var(--text);
      margin: 0;
      min-height: 100vh;
      line-height: 1.5;
    }}
    .banner {{
      background: linear-gradient(90deg, #b45309, var(--accent), #d97706);
      color: #0f1419;
      padding: 0.65rem 1.25rem;
      font-weight: 700;
      letter-spacing: 0.04em;
      text-align: center;
      font-size: 0.85rem;
    }}
    .wrap {{ max-width: 52rem; margin: 0 auto; padding: 1.5rem 1.25rem 3rem; }}
    h1 {{ font-size: 1.35rem; font-weight: 600; margin: 0 0 0.5rem; }}
    .sub {{ color: var(--muted); font-size: 0.95rem; margin-bottom: 1.5rem; }}
    .card {{
      background: var(--panel);
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 1rem 1.15rem;
      margin-bottom: 1rem;
    }}
    .card h2 {{ font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.06em; color: var(--muted); margin: 0 0 0.6rem; }}
    .status {{ display: flex; align-items: center; gap: 0.5rem; font-weight: 600; }}
    .dot {{ width: 10px; height: 10px; border-radius: 50%; }}
    .dot.ok {{ background: var(--ok); box-shadow: 0 0 10px var(--ok); }}
    .dot.bad {{ background: var(--bad); }}
    table {{ width: 100%; border-collapse: collapse; font-size: 0.9rem; }}
    th, td {{ text-align: left; padding: 0.45rem 0.5rem; border-bottom: 1px solid var(--border); }}
    th {{ color: var(--muted); font-weight: 500; font-size: 0.75rem; text-transform: uppercase; }}
    code {{ font-family: ui-monospace, monospace; font-size: 0.85em; background: #0f1419; padding: 0.15em 0.35em; border-radius: 4px; }}
    form {{ display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center; margin-top: 0.5rem; }}
    input[type="text"] {{
      flex: 1; min-width: 12rem;
      padding: 0.5rem 0.65rem;
      border: 1px solid var(--border);
      border-radius: 6px;
      background: #0f1419;
      color: var(--text);
    }}
    button {{
      padding: 0.5rem 1rem;
      border: none;
      border-radius: 6px;
      background: #3b82f6;
      color: white;
      font-weight: 600;
      cursor: pointer;
    }}
    button:hover {{ filter: brightness(1.08); }}
    .empty {{ color: var(--muted); font-size: 0.9rem; }}
    footer {{ margin-top: 2rem; font-size: 0.8rem; color: var(--muted); }}
    a {{ color: #93c5fd; }}
  </style>
</head>
<body>
  <div class="banner">DEMO ONLY — Not for production. Sample app for infrastructure exercises.</div>
  <div class="wrap">
    {inner}
    <footer>
      JSON API: <a href="/api/docs">/api/docs</a> · <code>/healthz</code> · <code>/metrics</code>
    </footer>
  </div>
</body>
</html>"""


@app.get("/", response_class=HTMLResponse)
def dashboard() -> HTMLResponse:
    db_ok = False
    db_error: str | None = None
    tables: list[str] = []
    items_rows: list[tuple[Any, ...]] = []

    try:
        with psycopg.connect(dsn(), connect_timeout=5) as conn:
            db_ok = True
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT table_name
                    FROM information_schema.tables
                    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
                    ORDER BY table_name
                    """
                )
                tables = [str(r[0]) for r in cur.fetchall()]
                cur.execute("SELECT id, name FROM items ORDER BY id LIMIT 100")
                items_rows = cur.fetchall()
    except (psycopg.Error, OSError, TimeoutError) as exc:
        db_error = f"{type(exc).__name__}: {exc}"

    status_html = ""
    if db_ok:
        status_html = '<div class="status"><span class="dot ok"></span> Connected to PostgreSQL</div>'
    else:
        err = html.escape(db_error or "Unknown error")
        status_html = f'<div class="status"><span class="dot bad"></span> Not connected</div><p class="sub" style="margin:0.5rem 0 0"><code>{err}</code></p>'

    if tables:
        rows = "".join(
            f"<tr><td><code>{html.escape(t)}</code></td></tr>" for t in tables
        )
        tables_block = f"<table><thead><tr><th>Table name</th></tr></thead><tbody>{rows}</tbody></table>"
    else:
        tables_block = '<p class="empty">No user tables in schema <code>public</code>.</p>'

    if items_rows:
        irows = "".join(
            f"<tr><td>{html.escape(str(r[0]))}</td><td>{html.escape(str(r[1]))}</td></tr>"
            for r in items_rows
        )
        items_block = f"""<table><thead><tr><th>id</th><th>name</th></tr></thead><tbody>{irows}</tbody></table>"""
    else:
        items_block = '<p class="empty">No rows in <code>items</code> yet.</p>'

    inner = f"""
    <h1>Demo API</h1>
    <p class="sub">This UI exists only to prove the stack: app ↔ PostgreSQL (CloudNativePG) in <code>app-dev</code>.</p>

    <div class="card">
      <h2>Database</h2>
      {status_html}
    </div>

    <div class="card">
      <h2>Tables in <code>public</code></h2>
      {tables_block}
    </div>

    <div class="card">
      <h2>Sample data — <code>items</code></h2>
      {items_block}
      <form method="post" action="/demo/item" autocomplete="off">
        <input type="text" name="name" placeholder="New item name" maxlength="200" required aria-label="Item name"/>
        <button type="submit">Add row</button>
      </form>
    </div>
    """
    return HTMLResponse(content=_page("Demo API", inner))


@app.post("/demo/item")
def add_demo_item(name: str = Form(...)) -> RedirectResponse:
    cleaned = (name or "").strip()
    if not cleaned:
        return RedirectResponse(url="/", status_code=303)
    with psycopg.connect(dsn()) as conn:
        with conn.cursor() as cur:
            cur.execute("INSERT INTO items(name) VALUES (%s)", (cleaned,))
    return RedirectResponse(url="/", status_code=303)


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


@app.post("/items")
def create_item(item: Item) -> dict:
    with psycopg.connect(dsn()) as conn:
        with conn.cursor() as cur:
            cur.execute("INSERT INTO items(name) VALUES (%s) RETURNING id", (item.name,))
            item_id = cur.fetchone()[0]
    return {"id": item_id, "name": item.name}


@app.get("/items")
def list_items() -> dict:
    with psycopg.connect(dsn()) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id, name FROM items ORDER BY id")
            rows = cur.fetchall()
    return {"items": [{"id": r[0], "name": r[1]} for r in rows]}
