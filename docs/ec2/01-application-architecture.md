# 01. EC2 Application Architecture — Comprehensive Notes

## 1. Architectural Overview

The VaultRix EC2 Application (`applications/ec2-app`) is a production-grade, containerized Python web application for managing tasks. It is designed to run statelessly inside Docker on Amazon EC2, backed by an encrypted Amazon RDS PostgreSQL database and configured via AWS Secrets Manager.

```
+---------------------------------------------------------------------------------------+
|                                APPLICATION COMPONENT STACK                            |
+--------------------+------------------------------------------------------------------+
| Framework          | Python 3.12 / Flask 3.0.3                                        |
| WSGI Server        | Gunicorn 22.0.0 (2 Worker Processes, 4 Threads per Worker)       |
| Database Driver    | psycopg2-binary 2.9.9 (RealDictCursor object factory)            |
| AWS SDK            | boto3 1.34.131 (Secrets Manager integration)                     |
| Container Runtime  | Docker Engine on Amazon Linux 2023 (Systemd service)             |
| Process Supervisor | Systemd (vaultrix-app.service with Restart=always)               |
+--------------------+------------------------------------------------------------------+
```

---

## 2. Directory Layout & File Responsibilities

```
applications/ec2-app/
├── app.py              # Main Flask application, API routes, DB logic & Secrets Manager client
├── Dockerfile          # Multi-stage production container image spec
├── requirements.txt    # Frozen Python dependencies
├── README.md           # Application-level developer reference
├── static/             # Static web assets
│   ├── css/
│   │   └── style.css   # Theme styling & dynamic environment status badges
│   └── js/
│       └── main.js     # Vanilla JavaScript AJAX client for task CRUD operations
└── templates/
    └── index.html      # Jinja2 template rendering web dashboard
```

---

## 3. Deep Dive: Application Logic (`applications/ec2-app/app.py`)

### A. Environment Configuration & Global State
```python
APP_ENV = os.environ.get("APP_ENV", "PRIMARY").upper()
DB_SECRET_ARN = os.environ.get("DB_SECRET_ARN", "")
PORT = int(os.environ.get("PORT", "8080"))

_db_config = None
_db_initialized = False
```
- `APP_ENV`: Identifies the active execution environment (`PRIMARY` or `DR`). Rendered on the web dashboard badge to visually verify region routing.
- `DB_SECRET_ARN`: The AWS Secrets Manager secret ARN holding database credentials.
- `_db_config`: Global in-memory cache variable storing parsed database connection parameters after initial secret retrieval.

---

### B. Dynamic Secrets Manager Credential Retrieval (`get_db_credentials()`)

The application dynamically fetches database credentials from AWS Secrets Manager using `boto3`. To optimize connection time and prevent API rate-limiting, credentials are cached in memory after the first call:

```python
def get_db_credentials():
    global _db_config
    if _db_config:
        return _db_config

    if not DB_SECRET_ARN:
        logger.warning("DB_SECRET_ARN not provided in environment.")
        return None

    try:
        # Extract AWS region from Secret ARN (e.g. arn:aws:secretsmanager:ap-south-1:598120810297:secret:...)
        arn_parts = DB_SECRET_ARN.split(":")
        region_name = arn_parts[3] if len(arn_parts) > 3 and arn_parts[3] else "ap-south-1"

        client = boto3.client("secretsmanager", region_name=region_name)
        response = client.get_secret_value(SecretId=DB_SECRET_ARN)

        if "SecretString" in response:
            secret_data = json.loads(response["SecretString"])
            _db_config = {
                "dbname": secret_data.get("dbname", "appdb"),
                "user": secret_data.get("username", "dbadmin"),
                "password": secret_data.get("password", ""),
                "host": secret_data.get("host", ""),
                "port": int(secret_data.get("port", 5432)),
                "connect_timeout": 5
            }
            logger.info(f"Successfully retrieved DB credentials for host: {_db_config['host']}")
            return _db_config
    except Exception as e:
        logger.error(f"Failed to fetch secret from Secrets Manager: {e}")
        return None
```

---

### C. Database Connection & Schema Initialization (`init_db()`)

When the application boots, it verifies that the PostgreSQL table `tasks` exists:

```python
def init_db():
    global _db_initialized
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS tasks (
                    id SERIAL PRIMARY KEY,
                    title VARCHAR(255) NOT NULL,
                    description TEXT,
                    priority VARCHAR(20) DEFAULT 'medium',
                    status VARCHAR(20) DEFAULT 'pending',
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );
            """)
            conn.commit()
        conn.close()
        _db_initialized = True
        logger.info("Database initialized successfully. Table 'tasks' verified.")
        return True
    except Exception as e:
        logger.warning(f"Database initialization deferred or failed: {e}")
        return False
```

---

### D. Complete HTTP API Endpoint Specification

#### 1. Web UI Route (`GET /`)
Renders `templates/index.html` with Jinja2 variable `app_env=APP_ENV`. Serves the user dashboard UI.

#### 2. Dedicated ALB Health Probe (`GET /health`)
```python
@app.route("/health")
def health():
    return jsonify({
        "status": "healthy",
        "environment": APP_ENV,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }), 200
```
- **Design Decision**: Deliberately executes **NO database queries**. Returning a fast HTTP 200 OK directly from Flask ensures that ALB and Route 53 health probes remain healthy even during temporary PostgreSQL query latency or database restoration jobs.

#### 3. System Status Endpoint (`GET /api/status`)
```python
@app.route("/api/status")
def api_status():
    ensure_db_initialized()
    creds = get_db_credentials()
    db_status = "disconnected"
    db_host = creds["host"] if creds else "N/A"
    db_name = creds["dbname"] if creds else "N/A"
    server_time = "N/A"
    task_count = 0

    if creds:
        try:
            conn = get_db_connection()
            with conn.cursor() as cur:
                cur.execute("SELECT NOW(), (SELECT COUNT(*) FROM tasks);")
                row = cur.fetchone()
                if row:
                    server_time = str(row[0])
                    task_count = row[1]
                db_status = "connected"
            conn.close()
        except Exception as e:
            logger.warning(f"Status endpoint DB check failed: {e}")

    return jsonify({
        "application": "healthy",
        "environment": APP_ENV,
        "database": db_status,
        "database_host": db_host,
        "database_name": db_name,
        "server_time": server_time,
        "task_count": task_count
    }), 200
```
- Returns comprehensive diagnostic JSON used by automated deployment scripts and DR drill workflows to verify database connection status.

#### 4. Explicit DB Ping (`GET /api/db-check`)
Executes `SELECT NOW()` on PostgreSQL. Returns HTTP 200 on success or HTTP 503 on database disconnect.

#### 5. Retrieve Tasks (`GET /api/tasks`)
Uses `psycopg2.extras.RealDictCursor` to query:
```sql
SELECT id, title, description, priority, status, 
       to_char(created_at, 'YYYY-MM-DD HH24:MI:SS') as created_at
FROM tasks 
ORDER BY created_at DESC;
```
Returns a JSON array of task objects.

#### 6. Create Task (`POST /api/tasks`)
Accepts JSON payload `{"title": "...", "description": "...", "priority": "high|medium|low"}`. Executes:
```sql
INSERT INTO tasks (title, description, priority, status)
VALUES (%s, %s, %s, 'pending')
RETURNING id, title, description, priority, status, to_char(created_at, 'YYYY-MM-DD HH24:MI:SS') as created_at;
```
Returns HTTP 201 Created with the new task JSON object.

#### 7. Complete Task (`PUT /api/tasks/<id>/complete`)
Updates task status column:
```sql
UPDATE tasks 
SET status = 'completed', updated_at = CURRENT_TIMESTAMP
WHERE id = %s
RETURNING id, title, status;
```
Returns HTTP 200 OK.

#### 8. Delete Task (`DELETE /api/tasks/<id>`)
Deletes record by ID:
```sql
DELETE FROM tasks WHERE id = %s RETURNING id;
```
Returns HTTP 200 OK.
