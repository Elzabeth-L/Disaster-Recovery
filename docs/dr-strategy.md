# Disaster Recovery Strategy

## Classification

The strategy is **cross-Region backup-and-restore with pilot-light networking**, also described as a cost-optimized pilot-light hybrid. It is not active-active or warm standby. Within Mumbai it provides cross-AZ recovery capacity, not full Multi-AZ availability.

## Failure domains and recovery layers

| Layer | Source of recovery | Limitation |
|---|---|---|
| Infrastructure | Terraform modules/root configurations | Provider/API/quota availability affects RTO |
| Desired app state | Version-controlled Kubernetes/app configuration | Does not contain live data or secrets |
| Kubernetes objects | Velero backups in S3 | Application consistency is not guaranteed by itself |
| EKS PostgreSQL | pgBackRest full/differential/WAL in S3 | Restore time and last archived WAL determine RTO/RPO |
| EBS/EC2 | AMIs and copied snapshots | Copies must exist in destination Region |
| RDS | Native automated backup/PITR plus pre-drill snapshot copy | Cross-Region copies are snapshot recovery points, not source PITR |

## Regional failover

1. Detect and alert from outside the failed workload.
2. An authorized human assesses scope and declares disaster/drill.
3. Freeze or account for writes; record the recovery point and start time.
4. Verify destination backups, quotas, credentials, and Terraform state.
5. Manually dispatch the approved DR workflow.
6. Create required egress and DR compute only.
7. Restore EC2/AMI/EBS and RDS; restore EKS infrastructure/add-ons, desired state, Velero objects, and PostgreSQL using the selected authoritative data recovery path.
8. Validate integrity, migrations, secrets, application health, and smoke tests.
9. Create/update the DR DNS target and obtain cutover approval.
10. Change Route 53 routing, monitor, and measure RTO/RPO.
11. Preserve logs, backup IDs, timestamps, test results, and exceptions.

No health check directly launches the DR environment.

## Failback

1. Declare the DR database authoritative and prevent split brain.
2. Rebuild and patch primary infrastructure without serving traffic.
3. Establish a controlled write freeze or replication/export window.
4. Back up authoritative DR data and transfer it to primary.
5. Restore primary databases and storage; validate counts/checksums and application versions.
6. Run smoke and recovery tests against non-public primary endpoints.
7. Approve Route 53 switchback, monitor, and reopen writes in one Region only.
8. Take evidence backups, then destroy temporary DR compute/ALBs/NAT/RDS/EKS while retaining policy-approved recovery points.

## Controlled scenarios

- EC2: process, instance, EBS loss, AMI restore, RDS PITR/snapshot, regional restore.
- EKS: Pod/node/namespace/PVC deletion, PostgreSQL corruption, cluster recreation, regional restore.
- Network/DNS: unhealthy primary endpoint and approved DNS cutover.

Never simulate a real AWS Region outage. Each drill has prechecks, abort criteria, data-integrity checks, cost cleanup, and an after-action report.

## Backup policy proposal

- EC2 golden AMI weekly/pre-release; mutable EBS daily with seven-day lab retention.
- RDS native automated backups/PITR with seven-day retention and a manual/cross-Region snapshot before drills. Use AWS Backup for a deliberately narrow demonstration, not duplicate continuous protection.
- Velero daily resource backup with configurable retention and CSI snapshot use only where destination-copy behavior is proven.
- pgBackRest weekly full, daily differential, continuous WAL, S3 versioning/encryption/lifecycle, and selective cross-Region replication.
- Exclude logs, monitoring scratch data, caches, and reproducible images from costly replication unless they are evidence requirements.

