import json
import logging
import os
from datetime import datetime
import boto3
from flask import Flask, jsonify, render_template, request
import psycopg2
from psycopg2.extras import RealDictCursor

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger("vaultrix-app")

app = Flask(__name__)

# Configuration from Environment
APP_ENV = os.environ.get("APP_ENV", "PRIMARY").upper()
DB_SECRET_ARN = os.environ.get("DB_SECRET_ARN", "")
PORT = int(os.environ.get("PORT", "8080"))

# Cached DB Configuration
_db_config = None


def get_db_credentials():
    """Retrieve database connection parameters from Secrets Manager or Environment."""
    global _db_config
    if _db_config:
        return _db_config

    if not DB_SECRET_ARN:
        logger.warning("DB_SECRET_ARN not provided in environment.")
        return None

    try:
        # Determine region from ARN or default to ap-south-1
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
        else:
            logger.error("SecretString not found in Secrets Manager response.")
            return None
    except Exception as e:
        logger.error(f"Failed to fetch secret from Secrets Manager: {e}")
        return None


def get_db_connection():
    """Create a new PostgreSQL database connection."""
    creds = get_db_credentials()
    if not creds:
        raise Exception("Database credentials unavailable.")

    conn = psycopg2.connect(
        dbname=creds["dbname"],
        user=creds["user"],
        password=creds["password"],
        host=creds["host"],
        port=creds["port"],
        connect_timeout=5
    )
    return conn


def init_db():
    """Ensure the tasks table exists without altering existing data."""
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
        logger.info("Database initialized successfully. Table 'tasks' verified.")
        return True
    except Exception as e:
        logger.warning(f"Database initialization deferred or failed: {e}")
        return False


# Attempt initial table creation on module load
init_db()


# -----------------------------------------------------------------------------
# Frontend Route
# -----------------------------------------------------------------------------
@app.route("/")
def index():
    """Serve main application UI."""
    return render_template("index.html", app_env=APP_ENV)


# -----------------------------------------------------------------------------
# ALB Health Check Endpoint (Fast, Independent of PostgreSQL)
# -----------------------------------------------------------------------------
@app.route("/health")
def health():
    """Dedicated AWS ALB Health Check endpoint."""
    return jsonify({
        "status": "healthy",
        "environment": APP_ENV,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }), 200


# -----------------------------------------------------------------------------
# API Endpoints
# -----------------------------------------------------------------------------
@app.route("/api/status")
def api_status():
    """Return application, database, and environment status metadata."""
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


@app.route("/api/db-check")
def api_db_check():
    """Perform explicit database connectivity check."""
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute("SELECT NOW(), (SELECT COUNT(*) FROM tasks);")
            row = cur.fetchone()
            server_time = str(row[0])
            task_count = row[1]
        conn.close()

        creds = get_db_credentials()
        return jsonify({
            "status": "connected",
            "environment": APP_ENV,
            "database_host": creds["host"] if creds else "N/A",
            "database_name": creds["dbname"] if creds else "N/A",
            "server_time": server_time,
            "task_count": task_count
        }), 200
    except Exception as e:
        logger.error(f"Explicit DB check failed: {e}")
        return jsonify({
            "status": "disconnected",
            "environment": APP_ENV,
            "error": "Failed to connect to database"
        }), 503


@app.route("/api/tasks", methods=["GET"])
def get_tasks():
    """Retrieve all tasks from PostgreSQL."""
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT id, title, description, priority, status, 
                       to_char(created_at, 'YYYY-MM-DD HH24:MI:SS') as created_at
                FROM tasks 
                ORDER BY created_at DESC;
            """)
            tasks = cur.fetchall()
        conn.close()
        return jsonify(list(tasks)), 200
    except Exception as e:
        logger.error(f"Error fetching tasks: {e}")
        return jsonify({"error": "Database service unavailable"}), 503


@app.route("/api/tasks", methods=["POST"])
def create_task():
    """Create a new task in PostgreSQL."""
    data = request.get_json() or {}
    title = data.get("title", "").strip()
    description = data.get("description", "").strip()
    priority = data.get("priority", "medium").lower()

    if not title:
        return jsonify({"error": "Task title is required"}), 400

    if priority not in ["low", "medium", "high"]:
        priority = "medium"

    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                INSERT INTO tasks (title, description, priority, status)
                VALUES (%s, %s, %s, 'pending')
                RETURNING id, title, description, priority, status,
                          to_char(created_at, 'YYYY-MM-DD HH24:MI:SS') as created_at;
            """, (title, description, priority))
            new_task = cur.fetchone()
            conn.commit()
        conn.close()
        logger.info(f"Task created: ID {new_task['id']}")
        return jsonify(dict(new_task)), 201
    except Exception as e:
        logger.error(f"Error creating task: {e}")
        return jsonify({"error": "Failed to create task"}), 503


@app.route("/api/tasks/<int:task_id>/complete", methods=["PUT"])
def complete_task(task_id):
    """Mark a task as completed."""
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                UPDATE tasks 
                SET status = 'completed', updated_at = CURRENT_TIMESTAMP
                WHERE id = %s
                RETURNING id, title, status;
            """, (task_id,))
            updated_task = cur.fetchone()
            conn.commit()
        conn.close()

        if not updated_task:
            return jsonify({"error": "Task not found"}), 404

        logger.info(f"Task completed: ID {task_id}")
        return jsonify(dict(updated_task)), 200
    except Exception as e:
        logger.error(f"Error completing task {task_id}: {e}")
        return jsonify({"error": "Failed to update task"}), 503


@app.route("/api/tasks/<int:task_id>", methods=["DELETE"])
def delete_task(task_id):
    """Delete a task from PostgreSQL."""
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute("DELETE FROM tasks WHERE id = %s RETURNING id;", (task_id,))
            deleted = cur.fetchone()
            conn.commit()
        conn.close()

        if not deleted:
            return jsonify({"error": "Task not found"}), 404

        logger.info(f"Task deleted: ID {task_id}")
        return jsonify({"message": f"Task {task_id} deleted successfully"}), 200
    except Exception as e:
        logger.error(f"Error deleting task {task_id}: {e}")
        return jsonify({"error": "Failed to delete task"}), 503


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PORT, debug=False)
