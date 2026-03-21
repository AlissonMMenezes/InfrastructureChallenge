import os

from fastapi import FastAPI
from pydantic import BaseModel
import psycopg


DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "app")
DB_USER = os.getenv("DB_USER", "app")
DB_PASSWORD = os.getenv("DB_PASSWORD", "app")

app = FastAPI(title="demo-api")


class Item(BaseModel):
    name: str


def dsn() -> str:
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
