# 08. Data Layer Architecture — Technical Notes

## 1. Overview & Data Storage Model

Unlike the EC2 workload which relies on Amazon RDS, the EKS application utilizes an **in-cluster PostgreSQL StatefulSet** backed by encrypted Amazon EBS `gp3` storage and configured via AWS Secrets Manager secrets.

```
+---------------------------------------------------------------------------------------------------+
| EKS DATA LAYER STACK                                                                              |
+--------------------------+------------------------------------------------------------------------+
| Database Container       | postgres:17.6-alpine (StatefulSet: postgres, 1 Replica)               |
| Driver / Connection      | psycopg (Python 3.13)                                                  |
| Storage Volume           | 8 GB encrypted gp3 EBS Volume (ebs.csi.aws.com provisioner)            |
| Headless Service         | postgres.notes.svc.cluster.local:5432                                  |
| Database Name            | notes                                                                  |
| Schema Auto-Creation     | CREATE TABLE IF NOT EXISTS notes (id, title, content, created_at)      |
| Credentials Safe         | AWS Secrets Manager secret: vaultrix-dr-primary-eks/notes/database     |
| Kubernetes Secret        | Secret: notes-database (keys: database, username, password, url)       |
+--------------------------+------------------------------------------------------------------------+
```

---

## 2. Secrets Management & Credential Injection Pipeline

Database credentials are not static. During pipeline execution ([`.github/workflows/eks-app-deploy.yml`](file:///c:/Users/smine/Disaster-Recovery/.github/workflows/eks-app-deploy.yml)), GitHub Actions checks AWS Secrets Manager:

1. **Secret Lookup**: Checks if secret `vaultrix-dr-primary-eks/notes/database` exists in AWS Secrets Manager.
2. **Password Generation**: If absent, generates a 32-byte secure random string via `openssl rand -base64 32` and stores it in Secrets Manager.
3. **Kubernetes Secret Creation**: Extracts `username`, `database`, `password`, and URL-encodes the password string to build a PostgreSQL connection URL:
   `postgresql://${username}:${encoded_password}@postgres:5432/${database}`
4. **Kubernetes Secret Injection**: Applies secret `notes-database` in namespace `notes`:
   ```bash
   kubectl -n notes create secret generic notes-database \
     --from-literal="database=${database}" \
     --from-literal="username=${username}" \
     --from-literal="password=${password}" \
     --from-literal="url=postgresql://${username}:${encoded_password}@postgres:5432/${database}" \
     --dry-run=client -o yaml | kubectl apply -f -
   ```
5. **Pod Environment Injection**: `app.yaml` references secret key `url` and maps it to environment variable `DATABASE_URL`:
   ```yaml
   env:
     - name: DATABASE_URL
       valueFrom:
         secretKeyRef:
           name: notes-database
           key: url
   ```

---

## 3. Schema Auto-Initialization (`PostgresNotes.ensure_schema()`)

When the `notes` application pod receives its first HTTP request, `PostgresNotes` executes:

```sql
CREATE TABLE IF NOT EXISTS notes (
  id BIGSERIAL PRIMARY KEY,
  title VARCHAR(120) NOT NULL,
  content VARCHAR(2000) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

- **Thread-Safety**: Uses `threading.Lock()` to prevent race conditions during schema verification across worker threads.
