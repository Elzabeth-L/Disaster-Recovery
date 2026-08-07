# RPO and RTO Objectives

These are project objectives, not AWS guarantees. Baselines are deliberately conservative for manual backup-and-restore and will be replaced with measured percentiles after drills.

| Scope | Initial RPO objective | Initial RTO objective | Evidence |
|---|---:|---:|---|
| EC2 application compute/config | Last release/AMI, <= 7 days for image; config in Git | 90 minutes | AMI timestamp, commit, healthy ALB test |
| EC2 mutable EBS data | <= 24 hours | 2 hours | Snapshot time, restored checksum |
| RDS PostgreSQL in-Region | <= 15 minutes with native PITR | 2 hours | selected restore timestamp, transaction marker |
| RDS cross-Region | <= 24 hours or last pre-drill copy | 3 hours | destination snapshot completion and marker |
| EKS infrastructure/application | Git commit plus <= 24-hour Velero object backup | 2 hours | cluster/add-on readiness and smoke tests |
| EKS PostgreSQL | <= 5 minutes target with continuous WAL; fallback <= 24 hours | 3 hours | last successfully archived WAL and restored marker |
| Kubernetes resources | <= 24 hours | 60 minutes after cluster/add-ons ready | Velero backup/restore status and object diff |
| Critical S3 objects | <= 15 minutes target replication time | 60 minutes | destination object version/checksum |
| Full regional service | Worst dependent RPO above | 4 hours | public smoke test after approved DNS cutover |

## Measurement method

Before a drill, write uniquely timestamped markers into each data store and record UTC start time, source backup IDs, last WAL archive success, and Git SHA. Start RTO when the authorized incident declaration occurs. End component RTO when its agreed functional/integrity checks pass; end service RTO when the public endpoint is healthy after DNS cutover.

Actual RPO is the time between the failure/declaration boundary and the newest durable marker present after restore. Record DNS TTL/cache effects separately from infrastructure/restore time. Report planned versus actual, data lost, manual wait time, restore throughput, failed attempts, and cleanup completion.

## Acceptance trend

The first drill establishes a baseline. A miss is not hidden by changing the target during the drill. Correct the runbook/automation/capacity, repeat the scenario, and retain both results. Shorter objectives require an explicit cost and architecture review, especially for database replication or warm standby.
