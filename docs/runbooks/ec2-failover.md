# VaultRix EC2 Disaster Recovery Failover Runbook

**Workload Boundary**: EC2 / RDS Application Stack (`@gokulk18`)  
**Primary Region**: `ap-south-1` (Mumbai)  
**DR Standby Region**: `ap-southeast-1` (Singapore)  
**Domain**: `ec2.dr.vaultrix.in`  

---

## 1. Executive Overview & Recovery Objectives

This runbook defines the operational procedure for executing a Disaster Recovery (DR) failover of the EC2 application stack from Primary (`ap-south-1`) to DR Standby (`ap-southeast-1`).

* **Recovery Point Objective (RPO)**: < 1 hour (Enforced by daily AWS Backup snapshots & transaction logs).
* **Recovery Time Objective (RTO)**: < 15 minutes (Enforced by automated Route 53 DNS failover & standby infrastructure).

---

## 2. Emergency Decision Matrix

Failover must be initiated under the following conditions:
1. **AWS Primary Regional Outage**: Complete loss of Availability Zones in `ap-south-1`.
2. **Persistent Hardware Failure**: Primary EC2 or RDS instance failure unresolvable within 15 minutes.
3. **Catastrophic Data Center Event**: Unrecoverable network partition impacting Primary ALB or VPC NAT Gateways.

---

## 3. Automated Failover Procedure

### Option A: Using CLI Automation Script (Recommended)

Execute the failover script from your management terminal:

```bash
cd D:\Gok\Disaster-Recovery
./scripts/failover/ec2-failover.sh
```

### Option B: Using GitHub Actions (Automated Drill / On-Demand)

1. Open **GitHub Repository** -> **Actions**.
2. Select **EC2 Disaster Recovery Automated Drill** (`.github/workflows/ec2-dr-test.yml`).
3. Click **Run workflow** against `main`.

---

## 4. Manual Step-by-Step Failover Procedure

If automated tools are unavailable, perform manual failover via AWS CLI:

### Step 1: Verify DR Standby Infrastructure
Ensure DR environment is provisioned in `ap-southeast-1`:
```powershell
cd terraform/environments/dr/ec2
terraform init "-backend-config=backend.hcl"
terraform apply -auto-approve
```

### Step 2: Retrieve DR ALB DNS Endpoint
```powershell
terraform output alb_dns_name
```

### Step 3: Trigger Route 53 Failover Record Flip
Update Route 53 DNS record for `ec2.dr.vaultrix.in` to route traffic to DR ALB:
```powershell
aws route53 change-resource-record-sets --hosted-zone-id <HOSTED_ZONE_ID> --change-batch file://failover-dns.json
```

---

## 5. Post-Failover Verification Checklist

- [ ] **ALB Health Endpoint**: Test `curl -i http://ec2.dr.vaultrix.in/health` (Expect `HTTP/1.1 200 OK` with `"environment": "DR"`).
- [ ] **Application Dashboard**: Open `http://ec2.dr.vaultrix.in/` in browser. Verify live badge displays **DR**.
- [ ] **Database Connection**: Create, update, and delete a test task in the UI. Confirm PostgreSQL persistence in `ap-southeast-1`.
