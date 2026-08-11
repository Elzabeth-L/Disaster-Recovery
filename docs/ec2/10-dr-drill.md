# 10. Disaster Recovery Drill Workflow — Comprehensive Notes

## 1. Overview & Workflow Trigger

The DR drill workflow ([`.github/workflows/dr-drill.yml`](file:///c:/Users/smine/Disaster-Recovery/.github/workflows/dr-drill.yml)) provides an interactive, workflow-dispatch pipeline to simulate regional failover and failback without permanent infrastructure destruction.

```yaml
name: DR 2 - Drill

on:
  workflow_dispatch:
    inputs:
      operation:
        description: Application preparation, traffic cutover, or application cleanup
        required: true
        type: choice
        options:
          - Deploy or refresh DR applications
          - Failover to DR
          - Failback to primary
          - Remove DR applications
      confirmation:
        description: Use DEMONSTRATE_DR for failover/failback or CLEANUP_DR_APPS for removal
        required: false
        type: string
```

---

## 2. Job 1: Seed & Validate DR Tasks (`deploy-ec2`)

Executed when `inputs.operation == 'Deploy or refresh DR applications'`:

1. **Capture Primary Tasks Snapshot**:
   ```bash
   curl --fail --retry 6 --retry-delay 5 http://ec2.dr.vaultrix.in/api/tasks -o "${RUNNER_TEMP}/tasks.json"
   ```
2. **Configure DR Credentials**:
   Assumes role `vars.AWS_EC2_APPLY_ROLE_ARN` in region `ap-southeast-1`.
3. **Verify DR ALB Health**:
   ```bash
   alb="$(aws elbv2 describe-load-balancers --names vaultrix-dr-dr-ec2-alb --query 'LoadBalancers[0].DNSName' --output text)"
   curl --fail --retry 30 --retry-delay 10 "http://${alb}/health"
   ```
4. **Purge & Seed DR Database**:
   - Queries `http://${alb}/api/tasks` and deletes old records via `DELETE http://${alb}/api/tasks/${id}`.
   - Iterates over `${RUNNER_TEMP}/tasks.json` and posts each task via `POST http://${alb}/api/tasks`.

---

## 3. Job 2: Controlled Automatic Failover (`cutover-ec2`)

Executed when `inputs.operation == 'Failover to DR'` and `inputs.confirmation == 'DEMONSTRATE_DR'`:

1. **Pre-Cutover Diagnostic Verification**:
   Queries diagnostic endpoint `http://ec2-dr.dr.vaultrix.in/api/status` to confirm DR environment is ready (`environment == "DR"` and `database == "connected"`).
2. **Simulate Primary Regional Outage**:
   Re-authenticates to `ap-south-1` and stops the Primary EC2 instance:
   ```bash
   instance_id="$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=vaultrix-dr-primary-ec2-instance' 'Name=instance-state-name,Values=running' --query 'Reservations[0].Instances[0].InstanceId' --output text)"
   aws ec2 stop-instances --instance-ids "${instance_id}"
   aws ec2 wait instance-stopped --instance-ids "${instance_id}"
   ```
3. **Assert Automatic Route 53 Failover**:
   Polls public domain `http://ec2.dr.vaultrix.in/api/status` until response returns `environment == "DR"`.

---

## 4. Job 3: Controlled Automatic Failback

Executed when `inputs.operation == 'Failback to primary'`:

1. **Restart Primary Instance**:
   ```bash
   instance_id="$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=vaultrix-dr-primary-ec2-instance' 'Name=instance-state-name,Values=stopped' --query 'Reservations[0].Instances[0].InstanceId' --output text)"
   aws ec2 start-instances --instance-ids "${instance_id}"
   aws ec2 wait instance-status-ok --instance-ids "${instance_id}"
   ```
2. **Assert Automatic Traffic Restoration**:
   Polls public domain `http://ec2.dr.vaultrix.in/api/status` until response returns `environment == "PRIMARY"`.
