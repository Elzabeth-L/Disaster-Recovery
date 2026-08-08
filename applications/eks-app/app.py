import os
import threading
from dataclasses import asdict, dataclass
from datetime import datetime, timezone

import psycopg
from flask import Flask, jsonify, render_template, request


@dataclass(frozen=True)
class Note:
    id: int
    title: str
    content: str
    created_at: str


class PostgresNotes:
    def __init__(self, database_url: str):
        self.database_url = database_url
        self._schema_ready = False
        self._schema_lock = threading.Lock()

    def _connect(self):
        if not self.database_url:
            raise RuntimeError("DATABASE_URL is required")
        return psycopg.connect(self.database_url, connect_timeout=5)

    def ensure_schema(self):
        if self._schema_ready:
            return
        with self._schema_lock:
            if self._schema_ready:
                return
            with self._connect() as connection, connection.cursor() as cursor:
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS notes (
                      id BIGSERIAL PRIMARY KEY,
                      title VARCHAR(120) NOT NULL,
                      content VARCHAR(2000) NOT NULL,
                      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                    )
                    """
                )
            self._schema_ready = True

    def ready(self):
        with self._connect() as connection, connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            return cursor.fetchone()[0] == 1

    def list(self):
        self.ensure_schema()
        with self._connect() as connection, connection.cursor() as cursor:
            cursor.execute(
                "SELECT id, title, content, created_at FROM notes ORDER BY created_at DESC, id DESC"
            )
            return [
                Note(
                    id=row[0],
                    title=row[1],
                    content=row[2],
                    created_at=row[3].astimezone(timezone.utc).isoformat(),
                )
                for row in cursor.fetchall()
            ]

    def create(self, title: str, content: str):
        self.ensure_schema()
        with self._connect() as connection, connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO notes (title, content)
                VALUES (%s, %s)
                RETURNING id, title, content, created_at
                """,
                (title, content),
            )
            row = cursor.fetchone()
            return Note(
                id=row[0],
                title=row[1],
                content=row[2],
                created_at=row[3].astimezone(timezone.utc).isoformat(),
            )

    def delete(self, note_id: int):
        self.ensure_schema()
        with self._connect() as connection, connection.cursor() as cursor:
            cursor.execute("DELETE FROM notes WHERE id = %s", (note_id,))
            return cursor.rowcount == 1


def create_app(repository=None):
    app = Flask(__name__)
    notes = repository or PostgresNotes(os.environ.get("DATABASE_URL", ""))

    @app.get("/")
    def index():
        return render_template("index.html")

    @app.get("/healthz")
    def health():
        return jsonify(status="ok")

    @app.get("/readyz")
    def readiness():
        try:
            return jsonify(status="ready" if notes.ready() else "not-ready")
        except Exception:
            app.logger.exception("Database readiness check failed")
            return jsonify(status="not-ready"), 503

    @app.get("/api/notes")
    def list_notes():
        return jsonify([asdict(note) for note in notes.list()])

    @app.post("/api/notes")
    def create_note():
        payload = request.get_json(silent=True) or {}
        title = str(payload.get("title", "")).strip()
        content = str(payload.get("content", "")).strip()
        if not title or len(title) > 120:
            return jsonify(error="title must contain 1-120 characters"), 400
        if not content or len(content) > 2000:
            return jsonify(error="content must contain 1-2000 characters"), 400
        return jsonify(asdict(notes.create(title, content))), 201

    @app.delete("/api/notes/<int:note_id>")
    def delete_note(note_id):
        if not notes.delete(note_id):
            return jsonify(error="note not found"), 404
        return "", 204

    return app


app = create_app()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
