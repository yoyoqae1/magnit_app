import sqlite3
import contextlib
from pathlib import Path
from app.config import settings

DB_PATH = settings.DATABASE_URL

if DB_PATH.startswith("sqlite:///"):
    DB_PATH = DB_PATH.replace("sqlite:///", "")


def get_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row   # строки как словари: row["id"] вместо row[0]
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    conn.execute("PRAGMA busy_timeout=5000")
    return conn


@contextlib.contextmanager
def get_db():
    """Контекстный менеджер — сам закрывает соединение и откатывает при ошибке."""
    conn = get_connection()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()