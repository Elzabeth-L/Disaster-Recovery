# Cost Plan

Prices vary by Region and date; verify with AWS Pricing Calculator before each phase. This architecture is cost-conscious, not permanently free-tier compatible. As of 2026-08-07, AWS lists a standard-support EKS control plane at $0.10/cluster-hour (about $73 for 730 hours) before nodes; extended support is $0.60/hour. Route 53 lists the first 25 hosted zones at $0.50/month. S3 gateway endpoints have no additional hourly charge.

## Service classification

| Service/resource | Lifecycle | Risk | Saving choice | Functionality lost |
|---|---|---:|---|---|
| VPC, subnets, route tables, IGW, SG | Always/pilot-light | Low | Keep; most have no hourly fee | None; public IPv4/data still billed |
| S3 gateway endpoint | Always | Low | Keep | S3 only, not general private egress |
| Route 53 hosted zone/queries | Always | Low | One delegated zone, ALB aliases | No independent zones per app |
| Terraform state S3 | Always storage | Low | Version lifecycle; SSE-S3 initially | Less key separation than CMK |
| Backup S3/snapshots/AMIs/vaults | Backup/storage only | Medium | Short lab retention, selective copies | Shorter recovery history |
| Cross-Region transfer/copy | Backup activity | Medium | Copy only critical data | Some artifacts need recreation |
| EKS control plane | Primary continuously during active project windows; DR drill only | High | Destroy/recreate primary outside those windows if budget requires | No continuously available demo between windows |
| EKS nodes/EBS/public IPv4 | With EKS | High | Small Graviton-compatible nodes, conservative requests, Spot for stateless later | Capacity/performance/interruption tolerance |
| NAT instance | With primary private EKS | Medium | Small AL2023 instance; S3 gateway endpoint | Single-AZ, limited throughput, self-managed |
| NAT Gateway | Fallback/DR drill | High | One only; destroy with cluster/drill | No AZ-resilient egress |
| Interface endpoints | Optional | Medium-High | Avoid until measured | Private API paths require NAT/public egress |
| ALBs | With applications/drill | High | Create only while testing; share only if ownership/security stays clear | No live public endpoint when destroyed |
| EC2 | Primary when app active; DR drill only | Medium-High | Small eligible instance/credits; stop/destroy | Availability/performance |
| RDS | Primary when app active; DR drill only | High | Small Single-AZ instance, short retention | No AZ HA; slower recovery |
| EBS | With compute plus snapshots | Medium | gp3, right-size, delete scratch volumes | Less headroom/history |
| CloudWatch logs/alarms/SNS | Selected always/temporary | Low-Medium | Short retention, metric filters, limited alarms | Less forensic depth |
| Prometheus/Grafana | Inside EKS | Medium | Single replicas, short retention, low resources | No HA/long history |
| AWS Backup | Narrow policy | Medium | Avoid duplicating native backups | Less AWS Backup demonstration breadth |
| Customer-managed KMS keys | Optional/backup requirement | Low-Medium | AWS-managed/SSE-S3 where valid | Less key-level isolation/control |

## Guardrails before infrastructure

1. Create an AWS Budget with alerts at agreed thresholds and confirmed email/SNS recipients.
2. Require `Project`, `Environment`, `Application`, `ManagedBy`, `Owner`, and `Expiration` tags.
3. Require manual GitHub Environment approval for any apply and every DR creation/cutover.
4. Show plan and cost-impact checklist in PRs; never schedule DR apply automatically.
5. Maintain a cleanup manifest for ALB, NAT, EKS, nodes, EC2, RDS, public IPv4, EBS, and stale snapshots.
6. Review Cost Explorer after each drill and compare estimated versus actual cost.
7. Use standard-support EKS versions to avoid sixfold extended-support control-plane pricing.

## Drill cleanup checklist

After evidence is preserved: direct traffic away; confirm backups; destroy DR application roots; verify EKS/node groups, EC2, RDS, ALBs, NAT/public IPv4, and unattached EBS are gone; retain only approved networking and recovery points; inspect state and AWS inventory; record final cost window.

## Cost references

- [Amazon EKS pricing](https://aws.amazon.com/eks/pricing/)
- [Amazon Route 53 pricing](https://aws.amazon.com/route53/pricing/)
- [S3 gateway endpoint pricing/behavior](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html)
- [AWS Backup cross-Region considerations](https://docs.aws.amazon.com/aws-backup/latest/devguide/cross-region-backup.html)
