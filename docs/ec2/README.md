# VaultRix EC2 Application & Disaster Recovery Architectural Guide

Welcome to the comprehensive developer learning guide for the **VaultRix EC2 Application** and its **Disaster Recovery (DR) Architecture**.

This guide explains the complete internal working, infrastructure dependencies, runtime behaviors, backup mechanisms, workflow files, and failover/failback mechanisms implemented in this repository.

---

## 1. Master System Sequence Diagrams

### Sequence Diagram 1: Active Production Request Processing Flow

This sequence shows how a user HTTP request is routed and processed during normal production operations when the Primary region (`ap-south-1`) is active and healthy.

```mermaid
sequenceDiagram
    autonumber
    actor User as User Browser / Client
    participant R53 as Route 53 DNS<br/>(ec2.dr.vaultrix.in)
    participant ALB as Primary ALB<br/>(Port 80)
    participant EC2 as Primary EC2 Instance<br/>(Port 8080)
    participant SM as AWS Secrets Manager
    participant RDS as Primary RDS PostgreSQL<br/>(Port 5432)

    User->>R53: 1. DNS Query for ec2.dr.vaultrix.in
    R53-->>User: 2. Return Primary ALB Public A-Record IP (ap-south-1)
    User->>ALB: 3. HTTP GET / (or POST /api/tasks) on Port 80
    ALB->>EC2: 4. Forward HTTP request to Target Group (Port 8080)

    rect rgb(240, 248, 255)
        note over EC2, SM: Secret Credential Retrieval
        alt Secret Credentials Cached in Memory?
            EC2->>EC2: Use cached _db_config dictionary
        else Secret Credentials Not Cached
            EC2->>SM: boto3.client('secretsmanager').get_secret_value(DB_SECRET_ARN)
            SM-->>EC2: Return SecretString JSON (host, port, dbname, user, pass)
            EC2->>EC2: Cache _db_config dictionary in memory
        end
    end

    EC2->>RDS: 5. Open TCP Connection & Execute SQL Query (Port 5432)
    RDS-->>EC2: 6. Return SQL Query Result Set
    EC2-->>ALB: 7. Return HTTP 200 OK + Rendered HTML/JSON Payload
    ALB-->>User: 8. Deliver HTTP Response to User Browser
```

---

### Sequence Diagram 2: Continuous Integration & Remote Deployment Pipeline

This sequence illustrates what happens when a developer pushes new application code to `applications/ec2-app/**`.

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Developer
    participant GH as GitHub Repository
    participant GHA as GitHub Actions Workflow<br/>(.github/workflows/ec2-app-build.yml)
    participant GHCR as GitHub Container Registry
    participant AWS_OIDC as AWS IAM OIDC Role
    participant SSM as AWS Systems Manager
    participant EC2 as Primary EC2 Instance

    Dev->>GH: 1. git push origin main (changes in applications/ec2-app/**)
    GH->>GHA: 2. Trigger "Primary 4 - EC2 application" workflow

    rect rgb(240, 248, 255)
        note over GHA, GHCR: Job 1: Container Build & Push
        GHA->>GHA: Execute Docker Buildx compilation from Dockerfile
        GHA->>GHCR: Authenticate using GITHUB_TOKEN
        GHA->>GHCR: Push tag ghcr.io/elzabeth-l/vaultrix-ec2-app:${github.sha}
        GHA->>GHCR: Update tag ghcr.io/elzabeth-l/vaultrix-ec2-app:latest
    end

    rect rgb(255, 245, 238)
        note over GHA, EC2: Job 2: Remote Deploy via SSM
        GHA->>AWS_OIDC: Assume Role (AWS_EC2_APPLY_ROLE_ARN via OpenID Connect)
        AWS_OIDC-->>GHA: Return temporary STS AWS credentials
        GHA->>SSM: Find instance tagged Name=vaultrix-dr-primary-ec2-instance
        GHA->>SSM: Send command: systemctl restart vaultrix-app.service
        SSM->>EC2: Execute systemctl restart vaultrix-app.service
        EC2->>GHCR: Docker pulls newest ghcr.io/.../vaultrix-ec2-app:latest
        EC2->>EC2: Recreate container on port 8080
        SSM-->>GHA: Command output (Status: Success)
    end
```

---

### Sequence Diagram 3: Automated Route 53 Health Check Failover

This sequence details how Route 53 automatically detects a failure in Mumbai (`ap-south-1`) and switches DNS routing to Singapore (`ap-southeast-1`).

```mermaid
sequenceDiagram
    autonumber
    participant R53_HC as Route 53 Health Checker
    participant PrimaryALB as Primary ALB (Mumbai)
    participant R53_DNS as Route 53 DNS Engine
    participant DRALB as DR ALB (Singapore)
    actor User as User Browser

    loop Every 30 Seconds
        R53_HC->>PrimaryALB: HTTP GET http://<Primary-ALB>/health
        PrimaryALB-->>R53_HC: HTTP 200 OK {"status":"healthy"}
    end

    note over PrimaryALB: Primary Regional Outage Occurs (Instance Crash / Network Failure)

    R53_HC->>PrimaryALB: HTTP GET http://<Primary-ALB>/health (Attempt 1)
    PrimaryALB--xR53_HC: Timeout / Connection Refused (Failure 1)

    note over R53_HC: Wait 30 seconds...
    R53_HC->>PrimaryALB: HTTP GET http://<Primary-ALB>/health (Attempt 2)
    PrimaryALB--xR53_HC: Timeout / Connection Refused (Failure 2)

    note over R53_HC: Wait 30 seconds...
    R53_HC->>PrimaryALB: HTTP GET http://<Primary-ALB>/health (Attempt 3)
    PrimaryALB--xR53_HC: Timeout / Connection Refused (Failure 3)

    note over R53_HC: Failure Threshold (3 consecutive checks = ~90s) Met!
    R53_HC->>R53_DNS: Mark PRIMARY Record Set as UNHEALTHY

    User->>R53_DNS: DNS Query for ec2.dr.vaultrix.in
    note over R53_DNS: Evaluate Failover Policy:<br/>PRIMARY is UNHEALTHY -> Route to SECONDARY (DR)
    R53_DNS-->>User: Return DR ALB Public A-Record IP (ap-southeast-1)
    User->>DRALB: HTTP GET / (Traffic successfully routed to DR Region!)
```

---

### Sequence Diagram 4: DR Database Snapshot Restoration Sequence

This sequence details how historical database state is restored in the DR region from the daily cross-region AWS Backup copy.

```mermaid
sequenceDiagram
    autonumber
    actor Operator as DR Operator / DevOps
    participant AWS_Backup as AWS Backup Service (ap-southeast-1)
    participant DR_Vault as DR Backup Vault<br/>(vaultrix-dr-dr-ec2-backup-vault)
    participant DR_RDS as DR RDS PostgreSQL Instance
    participant DR_SM as DR Secrets Manager
    participant DR_EC2 as DR EC2 Instance

    Operator->>AWS_Backup: 1. aws backup list-recovery-points-by-backup-vault --by-resource-type RDS
    AWS_Backup-->>Operator: Return latest copied RecoveryPointArn
    
    Operator->>AWS_Backup: 2. aws backup start-restore-job --recovery-point-arn <ARN> --metadata DBInstanceIdentifier=vaultrix-dr-dr-ec2-rds-restored
    AWS_Backup->>DR_Vault: Fetch encrypted snapshot
    DR_Vault->>DR_RDS: Provision restored RDS PostgreSQL instance
    
    loop Poll Status until AVAILABLE
        Operator->>DR_RDS: aws rds describe-db-instances
    end

    Operator->>DR_RDS: Retrieve restored DB Endpoint Address
    Operator->>DR_SM: 3. aws secretsmanager update-secret --secret-id vaultrix-dr-dr-ec2-db-credentials --secret-string JSON(restored_host)
    Operator->>DR_EC2: 4. aws ssm send-command --commands ["systemctl restart vaultrix-app.service"]
    DR_EC2->>DR_EC2: Restart Flask application container
    DR_EC2->>DR_SM: Fetch updated secret JSON payload
    DR_EC2->>DR_RDS: Connect to Restored PostgreSQL Database (Historical Data Active!)
```

---

### Sequence Diagram 5: Recovery & Failback Sequence to Primary Region

This sequence details how production traffic is safely returned to Mumbai after primary region stability has been restored.

```mermaid
sequenceDiagram
    autonumber
    actor Operator as Operator / Script
    participant Script as scripts/failback/ec2-failback.sh
    participant PrimaryALB as Primary ALB (Mumbai)
    participant R53 as Route 53 DNS Service
    actor User as User Browser

    Operator->>Script: Run ./scripts/failback/ec2-failback.sh
    Script->>PrimaryALB: HTTP GET http://<Primary-ALB>/health
    PrimaryALB-->>Script: HTTP 200 OK (Primary confirmed healthy!)

    alt Forced DNS Override Was Applied During Failover?
        Script->>R53: aws route53 change-resource-record-sets (Re-attach HealthCheckId to PRIMARY record)
        R53-->>Script: Route 53 Change Set Synced
    end

    Script->>R53: Inspect Primary Health Check Status
    R53-->>Script: Status = HEALTHY

    note over R53: Active-Passive Policy Re-evaluates:<br/>PRIMARY is HEALTHY -> Direct new DNS queries to Primary ALB

    User->>R53: DNS Query for ec2.dr.vaultrix.in
    R53-->>User: Return Primary ALB IP (ap-south-1)
    User->>PrimaryALB: HTTP GET / (Production traffic restored to Mumbai!)
```

---

## 2. Resource Responsibility Matrix

```
+---------------------------------------------------------------------------------------------------+
| RESOURCE RESPONSIBILITY MATRIX                                                                    |
+---------------------+---------------+-------------------+--------------------+--------------------+
| Component           | Primary       | DR                | Scope / Purpose    | Participation      |
+---------------------+---------------+-------------------+--------------------+--------------------+
| GHCR                | Shared        | Shared            | Container Registry | Immutable Images   |
| EC2 Instance        | Active (24/7) | Standby (Pilot)   | Application Host   | Runs Systemd/Docker|
| ALB                 | Active (24/7) | Standby (Pilot)   | Traffic Ingress    | Routes HTTP Port 80|
| RDS PostgreSQL      | Active (24/7) | Standby / Restored| Task Database      | Stores CRUD State  |
| AWS Secrets Manager | Active        | Active            | Credentials Safe   | Dynamic Auth       |
| Route 53            | Global        | Global            | DNS Router         | Failover Policy    |
| AWS Backup Vault    | Active        | Active            | Snapshot Storage   | Cross-Region Copy  |
| AWS SSM             | Active        | Active            | Remote Access      | Keyless Management |
+---------------------+---------------+-------------------+--------------------+--------------------+
```

---

## 3. Guide Index & Document Series

| Document | Title | Focus Area |
| :--- | :--- | :--- |
| [01-application-architecture.md](file:///c:/Users/smine/Disaster-Recovery/docs/ec2/01-application-architecture.md) | Application Architecture | Core Flask application structure, Gunicorn process model, endpoints, dynamic environment badges |
| [02-build-and-ghcr-workflow.md](file:///c:/Users/smine/Disaster-Recovery/docs/ec2/02-build-and-ghcr-workflow.md) | Build & Image Pipeline | Docker container build, multi-stage optimization, GHCR publishing, GitHub Actions build workflow |
| [03-infrastructure-provisioning.md](file:///c:/Users/smine/Disaster-Recovery/docs/ec2/03-infrastructure-provisioning.md) | Infrastructure Provisioning | Terraform state hierarchy (`global`, `shared`, `ec2`), module dependencies, remote backend configuration |
| [04-ec2-runtime.md](file:///c:/Users/smine/Disaster-Recovery/docs/ec2/04-ec2-runtime.md) | EC2 Runtime & Bootstrap | Amazon Linux 2023 bootstrap, `user_data.sh.tftpl`, Systemd service `vaultrix-app.service`, keyless SSM access |
| [05-alb-and-network-flow.md](file:///c:/Users/smine/Disaster-Recovery/docs/ec2/05-alb-and-network-flow.md) | ALB & Network Traffic Flow | Ingress networking, security group chains (`ALB SG -> EC2 SG -> RDS SG`), health checks on `/health` |
| [06-rds-and-secrets.md](file:///c:/Users/smine/Disaster-Recovery/docs/ec2/06-rds-and-secrets.md) | Database & Secrets Management | RDS PostgreSQL configuration, AWS Secrets Manager credential JSON, lazy in-memory credential caching |
| [07-backup-and-recovery.md](file:///c:/Users/smine/Disaster-Recovery/docs/ec2/07-backup-and-recovery.md) | AWS Backup & Data Protection | AWS Backup daily schedule (`cron(0 2 * * ? *)`), retention policies, dynamic cross-region copy rules |
| [08-dr-architecture.md](file:///c:/Users/smine/Disaster-Recovery/docs/ec2/08-dr-architecture.md) | Multi-Region DR Architecture | Primary (`ap-south-1`) vs DR (`ap-southeast-1`), pilot-light standby configuration, resource responsibility matrix |
| [09-dr-failover.md](file:///c:/Users/smine/Disaster-Recovery/docs/ec2/09-dr-failover.md) | DR Detection & Failover Mechanics | Route 53 Active-Passive failover routing policy, health probes, automated CLI failover, forced DNS override |
| [10-dr-drill.md](file:///c:/Users/smine/Disaster-Recovery/docs/ec2/10-dr-drill.md) | Disaster Recovery Drill Workflow | Interactive GitHub Actions workflow (`dr-drill.yml`), task data snapshot seeding, pre-failover verification |
| [11-failback.md](file:///c:/Users/smine/Disaster-Recovery/docs/ec2/11-failback.md) | Failback Mechanics & Data Sync | Primary health restoration, DNS record re-association (`ec2-failback.sh`), data reconciliation considerations |
| [12-complete-ec2-dr-flow.md](file:///c:/Users/smine/Disaster-Recovery/docs/ec2/12-complete-ec2-dr-flow.md) | Complete End-to-End Master Flow | End-to-end master sequence diagrams, 5-layer mental model, "One Request, One Disaster" scenario walkthrough |
| [13-github-actions-workflows-deep-dive.md](file:///c:/Users/smine/Disaster-Recovery/docs/ec2/13-github-actions-workflows-deep-dive.md) | GitHub Actions Workflows Deep Dive | Comprehensive analysis of `ec2-app-build.yml`, `ec2-platform.yml`, `dr-platform.yml`, `dr-drill.yml`, and `terraform-pr.yml` |
