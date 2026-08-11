# 12. Complete End-to-End Master Flow & Developer Mental Model — Comprehensive Notes

## 1. The 5-Layer Developer Mental Model

To understand how the VaultRix EC2 Application and its Disaster Recovery architecture function, think of the system in five interacting layers:

```
  Layer 1: Code        --> GitHub Repository (applications/ec2-app/)
  Layer 2: Artifact    --> GitHub Container Registry (ghcr.io image)
  Layer 3: Infra       --> Terraform Modules & State Roots (VPC, Subnets, SG, IAM)
  Layer 4: Runtime     --> ALB + EC2 + Systemd + Docker + Flask + RDS PostgreSQL
  Layer 5: Resilience  --> Route 53 + AWS Backup + DR Standby + Failover Runbooks
```

---

## 2. End-to-End Master Sequence Diagram

```mermaid
sequenceDiagram
    autonumber
    actor User as User Browser
    participant R53 as Route 53 DNS (ec2.dr.vaultrix.in)
    participant PriALB as Primary ALB (Mumbai)
    participant PriEC2 as Primary EC2 Instance
    participant PriSM as Primary Secrets Manager
    participant PriRDS as Primary RDS PostgreSQL
    participant PriVault as Primary Backup Vault
    participant DRVault as DR Backup Vault (Singapore)
    participant DRRDS as DR RDS PostgreSQL (Restored)
    participant DRALB as DR ALB (Singapore)

    rect rgb(240, 248, 255)
        note over User, PriRDS: 1. Normal Active Request Flow
        User->>R53: Query ec2.dr.vaultrix.in
        R53-->>User: Primary ALB Public IP (ap-south-1)
        User->>PriALB: HTTP GET /
        PriALB->>PriEC2: Forward HTTP GET to Target Group (Port 8080)
        PriEC2->>PriSM: Fetch DB Secret JSON via boto3
        PriSM-->>PriEC2: Return host, dbname, user, password
        PriEC2->>PriRDS: Execute SELECT * FROM tasks (Port 5432)
        PriRDS-->>PriEC2: Return query record set
        PriEC2-->>User: HTTP 200 OK + Rendered Task Dashboard HTML
    end

    rect rgb(255, 250, 205)
        note over PriRDS, DRVault: 2. Daily Snapshot & Cross-Region Copy
        PriRDS->>PriVault: Automated Daily Snapshot at 02:00 UTC
        PriVault->>DRVault: Copy snapshot to ap-southeast-1 backup vault
    end

    rect rgb(255, 235, 235)
        note over PriALB, DRALB: 3. Regional Outage & Automated Route 53 Failover
        note over PriALB: Primary Outage Occurs
        R53->>PriALB: Probe http://<Primary-ALB>/health (Fails 3x = ~90s)
        note over R53: Mark PRIMARY Unhealthy -> Select SECONDARY (DR)
        User->>R53: Query ec2.dr.vaultrix.in
        R53-->>User: DR ALB Public IP (ap-southeast-1)
    end

    rect rgb(230, 245, 230)
        note over DRVault, DRALB: 4. Snapshot Restoration & DR Traffic Active
        DRVault->>DRRDS: Restore Recovery Point to DR RDS Instance
        User->>DRALB: HTTP GET /
        DRALB-->>User: HTTP 200 OK (Dashboard Badge: DR)
    end
```

---

## 3. "One Request, One Disaster" Teaching Scenarios

### Scenario 1: Container Process Crash
- **What happens**: Gunicorn or Flask crashes inside the Docker container.
- **Systemd Behavior**: `vaultrix-app.service` configured with `Restart=always` and `RestartSec=10` automatically restarts the Docker container within 10 seconds.
- **ALB Behavior**: ALB temporarily routes traffic to backup worker threads. **Route 53 failover is NOT triggered**.

### Scenario 2: EC2 Instance Failure
- **What happens**: The underlying EC2 VM crashes or experiences a hardware fault.
- **ALB Behavior**: ALB Target Group health check fails.
- **Route 53 Behavior**: Route 53 health check probes fail 3 consecutive times (~90 seconds total).
- **Outcome**: Route 53 automatically switches DNS resolution for `ec2.dr.vaultrix.in` to the DR ALB in Singapore.

### Scenario 3: Complete Primary Region Outage (Mumbai Down)
- **What happens**: Complete loss of Availability Zones in `ap-south-1`.
- **Automatic Action**: Route 53 automatically switches DNS traffic to the pre-warmed DR ALB in Singapore.
- **Operator Action**: Operator runs `aws backup start-restore-job` in `ap-southeast-1` to restore the daily PostgreSQL snapshot, updates the DR Secrets Manager secret, and restarts `vaultrix-app.service` via SSM.
- **Outcome**: Application becomes fully operational in Singapore with historical data intact up to the last daily snapshot.
