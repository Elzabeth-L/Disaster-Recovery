from datetime import datetime, timezone

from app import Note, create_app


class MemoryNotes:
    def __init__(self):
        self.notes = []

    def ready(self):
        return True

    def list(self):
        return list(reversed(self.notes))

    def create(self, title, content):
        note = Note(
            id=len(self.notes) + 1,
            title=title,
            content=content,
            created_at=datetime.now(timezone.utc).isoformat(),
        )
        self.notes.append(note)
        return note

    def delete(self, note_id):
        original = len(self.notes)
        self.notes = [note for note in self.notes if note.id != note_id]
        return len(self.notes) != original


def client():
    application = create_app(MemoryNotes())
    application.config.update(TESTING=True)
    return application.test_client()


def test_health_and_readiness():
    test_client = client()
    assert test_client.get("/healthz").status_code == 200
    assert test_client.get("/readyz").status_code == 200


def test_note_lifecycle():
    test_client = client()
    response = test_client.post("/api/notes", json={"title": "DR", "content": "Test restore"})
    assert response.status_code == 201
    note = response.get_json()
    assert note["title"] == "DR"
    assert len(test_client.get("/api/notes").get_json()) == 1
    assert test_client.delete(f"/api/notes/{note['id']}").status_code == 204
    assert test_client.get("/api/notes").get_json() == []


def test_rejects_invalid_notes():
    test_client = client()
    assert test_client.post("/api/notes", json={"title": "", "content": "x"}).status_code == 400
    assert test_client.post("/api/notes", json={"title": "x", "content": ""}).status_code == 400
