# Vaultrix Notes - EKS application

A small Flask/PostgreSQL notes application used to prove Kubernetes infrastructure, persistent storage, backup, restore, and DNS cutover behavior.

## Endpoints

- `GET /healthz`: process liveness; deliberately independent of PostgreSQL.
- `GET /readyz`: PostgreSQL connectivity readiness.
- `GET /api/notes`: list notes.
- `POST /api/notes`: create a note from JSON `title` and `content`.
- `DELETE /api/notes/{id}`: delete a note.

## Local development

```bash
python -m venv .venv
. .venv/bin/activate
pip install -r requirements-dev.txt
pytest -q
```

Set `DATABASE_URL` to a PostgreSQL connection string before starting the real application. Tests use an in-memory repository and do not require a database.

The image runs as UID/GID `10001`, exposes port `8080`, and contains no credentials. CI builds immutable commit-tagged images; deployment retrieves the database password from AWS Secrets Manager without committing it to Git or Terraform state.
