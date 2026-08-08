# VaultRix EC2 Disaster Recovery Failback Runbook

**Workload Boundary**: EC2 / RDS Application Stack (`@gokulk18`)  
**Primary Region**: `ap-south-1` (Mumbai)  
**DR Region**: `ap-southeast-1` (Singapore)  
**Domain**: `ec2.dr.vaultrix.in`  

---

## 1. Executive Overview & Failback Criteria

This runbook defines the operational procedure for restoring primary production traffic from DR (`ap-southeast-1`) back to Primary (`ap-south-1`) after Primary region stability has been verified.

### Failback Prerequisites
1. **Primary Region Restored**: AWS service health in `ap-south-1` is 100% normal.
2. **Primary Stack Healthy**: Primary ALB, EC2, RDS, and Secrets Manager are online and responding to `/health`.
3. **Data Synchronized**: Final PostgreSQL data sync or recovery point restore from DR back to Primary is verified.

---

## 2. Automated Failback Procedure

### Option A: Using CLI Automation Script (Recommended)

Execute the failback script from your management terminal:

```bash
cd D:\Gok\Disaster-Recovery
./scripts/failback/ec2-failback.sh
```

---

## 3. Manual Step-by-Step Failback Procedure

### Step 1: Health Pre-Check on Primary ALB
Verify Primary ALB responds with HTTP 200 OK:
```powershell
curl -i http://<PRIMARY_ALB_DNS>/health
```

### Step 2: Revert Route 53 DNS Record to PRIMARY
Revert Route 53 failover policy to direct active traffic to Primary (`ap-south-1`):
```powershell
aws route53 change-resource-record-sets --hosted-zone-id <HOSTED_ZONE_ID> --change-batch file://failback-dns.json
```

### Step 3: Verify Global DNS Propagation
```powershell
nslookup ec2.dr.vaultrix.in
```

---

## 4. Post-Failback Verification Checklist

- [ ] **Primary UI**: Open `http://ec2.dr.vaultrix.in/` in browser. Confirm badge displays **PRIMARY**.
- [ ] **Primary Database**: Perform a task CRUD operation. Confirm records write to Primary RDS in `ap-south-1`.
- [ ] **DR Standby Reset**: Reset DR environment back to Standby mode.
