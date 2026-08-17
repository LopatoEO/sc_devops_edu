import os
import json
from typing import Optional

from fastapi import FastAPI
from fastapi import HTTPException
from pydantic import BaseModel
import psycopg2
import psycopg2.extras
import redis
from celery import Celery

app = FastAPI()

DATABASE_URL = os.environ.get("DATABASE_URL")
REDIS_URL = os.environ["REDIS_URL"]
EVENTS_CACHE_TTL = int(os.environ.get("EVENTS_CACHE_TTL", "30"))  # секунды

EVENTS_CACHE_KEY = "cache:events:all"

r = redis.Redis.from_url(REDIS_URL)
celery_app = Celery("tasks", broker=REDIS_URL)


class EventIn(BaseModel):
    name: str
    payload: Optional[dict] = None


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


def fetch_events_from_db():
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("SELECT id, name, payload, created_at FROM events ORDER BY id")
    rows = cur.fetchall()
    cur.close()
    conn.close()

    # datetime и так не сериализуется в JSON напрямую - приводим к строке.
    # payload psycopg2 уже возвращает как dict (тип колонки JSONB).
    events = []
    for row in rows:
        events.append({
            "id": row["id"],
            "name": row["name"],
            "payload": row["payload"],
            "created_at": row["created_at"].isoformat(),
        })
    return events


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/db-check")
def db_check():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT 1")
    result = cur.fetchone()
    conn.close()
    if result[0] == 0:
        raise HTTPException(
        status_code=503,
        detail="Service unavailable"
        )
    return {"db": result[0]}


@app.get("/redis-check")
def redis_check():
    r.set("ping", "pong")
    return {"redis": r.get("ping").decode()}


@app.get("/events")
def get_events():
    """
    Отдаёт список событий.
    Сначала проверяет кэш в Redis. Если данных там нет (промах кэша) -
    идёт в Postgres, кладёт результат в Redis с TTL и отдаёт его.
    Поле "source" показывает, откуда фактически пришёл ответ: cache или db.
    Вторая версия
    """
    cached = r.get(EVENTS_CACHE_KEY)
    if cached is not None:
        return {
            "source": "cache",
            "events": json.loads(cached),
        }

    events = fetch_events_from_db()
    r.set(EVENTS_CACHE_KEY, json.dumps(events), ex=EVENTS_CACHE_TTL)

    return {
        "source": "db",
        "events": events,
    }


@app.post("/events")
def post_event(event: EventIn):
    """
    Принимает событие (name + произвольный payload) и НЕ пишет его в БД сама.
    api только кладёт задачу в очередь Celery - реальную запись в Postgres
    делает worker. Поэтому ответ отдаётся сразу, до того как строка
    физически появится в таблице events (async-запись).

    Кэш /events инвалидируется сразу же: raз данные в БД скоро изменятся,
    старый список в Redis больше не актуален. Если этого не сделать,
    GET /events будет отдавать устаревший список вплоть до истечения TTL.
    """
    celery_app.send_task(
        "worker.create_event",
        args=[event.name, event.payload or {}],
    )
    r.delete(EVENTS_CACHE_KEY)

    return {"queued": True, "name": event.name, "payload": event.payload}


@app.post("/events/cache/invalidate")
def invalidate_events_cache():
    """
    Явный сброс кэша вручную - на случай, если нужно сбросить кэш
    без создания нового события (например, после ручного вмешательства в БД).
    """
    deleted = r.delete(EVENTS_CACHE_KEY)
    return {"invalidated": bool(deleted)}
