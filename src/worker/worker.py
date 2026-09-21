import os
import json

import psycopg2
from celery import Celery

REDIS_URL = os.environ["REDIS_URL"]
DATABASE_URL = os.environ.get("DATABASE_URL")

app = Celery("worker", broker=REDIS_URL)


def get_db_connection():
    if DATABASE_URL:
        return psycopg2.connect(DATABASE_URL)

    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=os.environ.get("DB_PORT", "5432"),
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
        dbname=os.environ["POSTGRES_DB"],
    )


@app.task(name="worker.create_event")
def create_event(name: str, payload: dict | None = None):
    """
    Принимает имя события и произвольный payload, пишет строку в таблицу events.
    Именно worker делает запись в БД - api только ставит задачу в очередь
    и сразу отвечает клиенту, не дожидаясь физической записи в Postgres.
    """
    payload = payload or {}

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO events (name, payload) VALUES (%s, %s) RETURNING id",
        (name, json.dumps(payload)),
    )
    event_id = cur.fetchone()[0]
    conn.commit()
    cur.close()
    conn.close()

    print(f"event written: id={event_id} name={name} payload={payload}")
    return {"id": event_id, "name": name, "payload": payload}
