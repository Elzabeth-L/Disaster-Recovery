# VaultRix Tasks — Disaster Recovery Demonstration Platform

**VaultRix Tasks** is a lightweight, high-performance containerized web application built with Python 3.12, Flask, Gunicorn, PostgreSQL (`psycopg2`), and AWS Secrets Manager (`boto3`).

It serves as the application workload for the **VaultRix AWS Disaster Recovery Project**, running inside a private EC2 instance behind an internet-facing Application Load Balancer (ALB) and connecting to a private Amazon RDS PostgreSQL database.

---

## 1. Architecture Flow

```text
User Browser
    │
    │  HTTP :80 (Public Internet)
    ▼
AWS Application Load Balancer (ALB)
    │
    │  HTTP :8080 (Private VPC Subnet)
    ▼
EC2 Instance (Gunicorn / Flask Container)
    │
    ├──► AWS Secrets Manager (boto3 / IAM Instance Role)
    │    └── Fetches Database Credentials JSON at runtime
    │
    └──► Private Amazon RDS PostgreSQL (TCP :5432)
         └── Persists tasks table across Primary & DR environments
```

---

## 2. Environment Variables

| Variable Name | Required | Default | Description |
| :--- | :--- | :--- | :--- |
| `APP_ENV` | No | `PRIMARY` | Region / Environment badge displayed in UI (`PRIMARY` or `DR`). |
| `PORT` | No | `8080` | Port for Gunicorn / Flask container listener. |
| `DB_SECRET_ARN` | **Yes** (for DB) | `""` | AWS Secrets Manager Secret ARN containing database credentials. |

---

## 3. Database Schema

The application automatically creates the `tasks` table on startup if it does not already exist:

```sql
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    priority VARCHAR(20) DEFAULT 'medium',
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

---

## 4. API Endpoints

### Frontend & Health Checks
* `GET /`: Renders the main dashboard UI (`templates/index.html`).
* `GET /health`: **AWS ALB Health Check**. Returns HTTP 200 OK fast (`{"status": "healthy"}`). Does **not** require PostgreSQL connectivity.

### Application APIs
* `GET /api/status`: Returns application, database connection state, DB host, server time, and task count.
* `GET /api/db-check`: Triggers explicit database ping and server time check.
* `GET /api/tasks`: Fetches all tasks ordered by creation time.
* `POST /api/tasks`: Creates a new task (`{"title": "...", "description": "...", "priority": "high"}`).
* `PUT /api/tasks/<id>/complete`: Marks task `#id` as completed.
* `DELETE /api/tasks/<id>`: Deletes task `#id`.

---

## 5. Local Docker Execution

### Build Docker Image
```bash
docker build -t vaultrix-app:latest .
```

### Run Locally (Without AWS DB)
```bash
docker run -d \
  --name vaultrix-app \
  -p 8080:8080 \
  -e APP_ENV=LOCAL \
  vaultrix-app:latest
```
*Access UI at `http://localhost:8080` and health check at `http://localhost:8080/health`.*

### Run Locally (With AWS Secrets Manager)
```bash
docker run -d \
  --name vaultrix-app \
  -p 8080:8080 \
  -e APP_ENV=PRIMARY \
  -e DB_SECRET_ARN=arn:aws:secretsmanager:ap-south-1:123456789012:secret:vaultrix-dr-primary-ec2-db-credentials-xxxxxx \
  -e AWS_REGION=ap-south-1 \
  -v ~/.aws:/root/.aws:ro \
  vaultrix-app:latest
```

---

## 6. Disaster Recovery Demonstration

During a disaster recovery drill:
1. **Primary Deployment**: Container runs with `APP_ENV=PRIMARY` pointing to Primary RDS in Mumbai (`ap-south-1`).
2. **DR Deployment**: Container runs with `APP_ENV=DR` pointing to DR RDS in Singapore (`ap-southeast-1`).
3. **Data Verification**: Tasks created in Primary appear in DR after database failover, visibly demonstrating data persistence and replication.
