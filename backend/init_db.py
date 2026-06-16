import sqlite3
import os

DB_PATH = "magnit.db"

def init_database():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    conn.execute("PRAGMA busy_timeout=5000")  #ждём 5 сек если бд занята

    cursor = conn.cursor()

    #таблица пользователей, задач, 
    cursor.executescript("""
        CREATE TABLE IF NOT EXISTS users (
            id               INTEGER PRIMARY KEY AUTOINCREMENT,
            username         TEXT    NOT NULL UNIQUE COLLATE NOCASE,
            hashed_password  TEXT    NOT NULL,
            role             TEXT    NOT NULL CHECK(role IN ('director', 'senior_seller', 'seller')),
            is_active        BOOLEAN NOT NULL DEFAULT 1,
            created_at       DATETIME NOT NULL DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS tasks (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            title        TEXT    NOT NULL CHECK(length(title) >= 3),
            description  TEXT,
            status       TEXT    NOT NULL DEFAULT 'new'
                             CHECK(status IN ('new', 'in_progress', 'done')),
            creator_id   INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
            assignee_id  INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
            created_at   DATETIME NOT NULL DEFAULT (datetime('now')),
            updated_at   DATETIME NOT NULL DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS refresh_tokens (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            token_hash  TEXT    NOT NULL UNIQUE,
            expires_at  DATETIME NOT NULL,
            revoked     BOOLEAN NOT NULL DEFAULT 0,
            created_at  DATETIME NOT NULL DEFAULT (datetime('now'))
        );

        -- Индексы для быстрого поиска
        CREATE INDEX IF NOT EXISTS idx_tasks_assignee  ON tasks(assignee_id);
        CREATE INDEX IF NOT EXISTS idx_tasks_creator   ON tasks(creator_id);
        CREATE INDEX IF NOT EXISTS idx_tasks_status    ON tasks(status);
        CREATE INDEX IF NOT EXISTS idx_refresh_user    ON refresh_tokens(user_id);
        CREATE INDEX IF NOT EXISTS idx_refresh_hash    ON refresh_tokens(token_hash);

        -- Триггер: автообновление updated_at при изменении задачи
        CREATE TRIGGER IF NOT EXISTS tasks_updated_at
            AFTER UPDATE ON tasks
            FOR EACH ROW
            BEGIN
                UPDATE tasks SET updated_at = datetime('now') WHERE id = OLD.id;
            END;
    """)

    conn.commit()
    conn.close()
    print(f"БД создана: {os.path.abspath(DB_PATH)}")

if __name__ == "__main__":
    init_database()