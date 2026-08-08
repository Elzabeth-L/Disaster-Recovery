# VaultRix EC2 Disaster Recovery Failover Runbook

**Workload Boundary**: EC2 / RDS Application Stack (`@gokulk18`)  
**Primary Region**: `ap-south-1` (Mumbai)  
**DR Standby Region**: `ap-southeast-1` (Singapore)  
**Domain**: `ec2.dr.vaultrix.in`  

---

## 1. Executive Overview & Recovery Objectives

This runbook defines the operational procedure for executing a Disaster Recovery (DR) failover of the EC2 application stack from Primary (`ap-south-1`) to DR Standby (`ap-southeast-1`).

* **Recovery Point Objective (RPO)**: **< 26 hours** — enforced by daily cross-region AWS Backup copies from Primary vault to DR vault (`ap-southeast-1`). The most recent DR backup snapshot is at most 24 hours old plus copy lag.
* **Recovery Time Objective (RTO)**: **< 15 minutes** — enforced by automated Route 53 DNS failover (3 failed health checks × 30s interval = 90 second trigger) and pre-warmed DR standby infrastructure.

> [!NOTE]
> For a sub-hour RPO, configure RDS Cross-Region Read Replica promotion (Phase 14). The current architecture uses daily backups; any data written between the last backup and the failure event will be lost.

---

## 2. Emergency Decision Matrix

Failover must be initiated under the following conditions:
1. **AWS Primary Regional Outage**: Complete loss of Availability Zones in `ap-south-1`.
2. **Persistent Hardware Failure**: Primary EC2 or RDS instance failure unresolvable within 15 minutes.
3. **Catastrophic Data Center Event**: Unrecoverable network partition impacting Primary ALB or VPC NAT Gateways.

---

## 3. Pre-Failover Checklist

Before initiating failover, confirm:

- [ ] Primary failure is confirmed (not a transient blip) — wait 5 minutes and observe Route 53 health check status
- [ ] DR environment is provisioned and DR ALB `/health` returns 200 in `ap-southeast-1`
- [ ] Most recent backup copy exists in DR vault — see Section 5 for restoration steps

---

## 4. Automated Failover Procedure

### Option A: Using CLI Automation Script (Recommended — Monitor Mode)

Monitors current state. Route 53 DNS failover is automatic when Primary health checks fail:

```bash
cd D:\Gok\Disaster-Recovery
./scripts/failover/ec2-failover.sh
```

### Option B: Force Immediate DNS Failover (Emergency Override)

Use when Primary health check recovery is too slow and immediate manual DNS override is needed:

```bash
FORCE_FAILOVER=true ./scripts/failover/ec2-failover.sh
```

This removes the health check association from the PRIMARY Route 53 record, causing immediate traffic redirection to the SECONDARY (DR) record.

### Option C: GitHub Actions (Automated Weekly Drill / On-Demand Verification)

1. Open **GitHub Repository** → **Actions**.
2. Select **EC2 Disaster Recovery Automated Drill** (`.github/workflows/ec2-dr-test.yml`).
3. Click **Run workflow** against `main`.

---

## 5. DR Database Restore from Backup

> [!IMPORTANT]
> The DR RDS instance starts with an **empty** database. Before the DR application can serve live data, restore the most recent backup copy from the DR vault.

### Step 1: Find the Most Recent Recovery Point in DR Vault

```bash
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name vaultrix-dr-dr-ec2-backup-vault \
  --region ap-southeast-1 \
  --by-resource-type RDS \
  --query "RecoveryPoints | sort_by(@, &CreationDate) | [-1].{ARN:RecoveryPointArn, Date:CreationDate, Status:Status}" \
  --output table
```

### Step 2: Restore the Recovery Point to a New RDS Instance

```bash
aws backup start-restore-job \
  --recovery-point-arn "<RECOVERY_POINT_ARN_FROM_STEP_1>" \
  --iam-role-arn "arn:aws:iam::598120810297:role/vaultrix-dr-dr-ec2-backup-role" \
  --metadata '{"DBInstanceIdentifier":"vaultrix-dr-dr-ec2-rds-restored","DBSubnetGroupName":"vaultrix-dr-dr-ec2-db-subnet-group"}' \
  --resource-type RDS \
  --region ap-southeast-1
```

### Step 3: Update Secrets Manager with Restored Endpoint

Once the restored RDS instance is available, update the DR Secrets Manager secret with the new endpoint:

```bash
RESTORED_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier vaultrix-dr-dr-ec2-rds-restored \
  --region ap-southeast-1 \
  --query "DBInstances[0].Endpoint.Address" --output text)

aws secretsmanager update-secret \
  --secret-id vaultrix-dr-dr-ec2-db-credentials \
  --region ap-southeast-1 \
  --secret-string "{\"engine\":\"postgres\",\"host\":\"${RESTORED_ENDPOINT}\",\"port\":5432,\"dbname\":\"appdb\",\"username\":\"dbadmin\",\"password\":\"<original-password>\"}"
```

### Step 4: Restart DR Application to Pick Up New Credentials

```bash
DR_INSTANCE_ID=$(aws ec2 describe-instances \
  --region ap-southeast-1 \
  --filters "Name=tag:Name,Values=vaultrix-dr-dr-ec2-instance" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" --output text)

aws ssm send-command \
  --region ap-southeast-1 \
  --instance-ids "${DR_INSTANCE_ID}" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["systemctl restart vaultrix-app.service"]'
```

---

## 6. Manual Step-by-Step Failover Procedure (No CLI Script)

If automation scripts are unavailable, perform manual failover via AWS Console or CLI:

### Step 1: Verify DR Standby Infrastructure

Ensure DR environment is provisioned in `ap-southeast-1`:
```powershell
cd terraform/environments/dr/ec2
terraform init "-backend-config=backend.hcl"
terraform plan
```

### Step 2: Retrieve DR ALB DNS Endpoint
```powershell
terraform output alb_dns_name
```

### Step 3: Confirm DNS Failover is Active
Route 53 failover is automatic. To verify:
```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id <HOSTED_ZONE_ID> \
  --query "ResourceRecordSets[?Name=='ec2.dr.vaultrix.in.']" \
  --output table
```

---

## 7. Post-Failover Verification Checklist

- [ ] **ALB Health Endpoint**: Test `curl -i http://ec2.dr.vaultrix.in/health` (Expect `HTTP/1.1 200 OK` with `"environment": "DR"`).
- [ ] **Application Dashboard**: Open `http://ec2.dr.vaultrix.in/` in browser. Verify live badge displays **DR**.
- [ ] **Database Connection**: Create a test task in the UI. Confirm PostgreSQL persistence in `ap-southeast-1`.
- [ ] **Data Continuity**: Confirm backup restore was performed (see Section 5). Acknowledge any RPO data gap.
- [ ] **CloudWatch Alarms**: Verify no unresolved alarms in `ap-southeast-1` CloudWatch console.
- [ ] **Notify Stakeholders**: Communicate DR activation, estimated resolution time, and data gap window.
