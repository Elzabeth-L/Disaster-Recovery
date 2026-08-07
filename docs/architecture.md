# Architecture

Status: proposed for approval on 2026-08-07. No AWS resources exist.

## Current repository assessment

The workspace initially contained only `docs/project-context.md`. It was not a Git repository and had no README, Terraform, Kubernetes, CI, application, or AWS configuration. There are therefore no implementation conflicts, migrations, or user changes to preserve. The mojibake visible in the supplied prompt is a text-encoding issue only; its intent remains readable.

## Proposed architecture

The platform has a global/bootstrap layer and two regional environments. `ap-south-1` is primary and `ap-southeast-1` is DR. Each Region has its own VPC and two-AZ subnet capacity. Only networking, backup storage, recovery artifacts, and configuration remain in DR between drills. EKS, nodes, EC2, RDS, and ALBs are created only after a human declares a drill or disaster.

The two application tracks are independently owned:

- EKS: ALB -> EKS application -> PostgreSQL StatefulSet on EBS gp3; Terraform, version-controlled desired state, Velero, and pgBackRest form distinct recovery layers.
- EC2: ALB -> EC2/ASG -> RDS PostgreSQL; golden AMIs, EBS/RDS backups, AWS Backup where it adds learning value, and CloudWatch provide recovery mechanisms.

Route 53 owns `dr.vaultrix.in`, delegated from GoDaddy. Application stacks own only their records. A regional failover is deliberately human-approved: DR compute is built and restored, tested, then DNS is changed.

Diagram source is in [architecture/overview.mmd](architecture/overview.mmd).

## Architecture Review and Recommendations

### Required corrections

1. **Free-tier claim:** The complete design is not free-tier eligible. EKS control planes, ALBs, NAT or interface endpoints, Route 53, snapshots, cross-Region transfer, and usually RDS/EC2/EBS produce charges. Documentation and budgets must say credit/free-tier dependent, not free.
2. **Private EKS egress:** An S3 gateway endpoint reaches only S3. Private nodes also need paths to ECR API/Docker, STS, EC2 APIs, public image/chart registries, and possibly CloudWatch. Select one documented egress mode before EKS: a temporary/single NAT path, paid interface endpoints, or a less-secure public-node lab mode.
3. **DNS failover target:** Route 53 cannot fail over to an ALB that does not exist. With backup-and-restore DR, create and validate the DR endpoint first, then add/update the secondary record and approve cutover. Fully automatic failover is incompatible with a normally absent DR stack.
4. **State model:** Add `bootstrap` and `global/shared` state. The backend bucket cannot be created by a configuration already using that backend, and Route 53/OIDC are global/account resources rather than properties of both regional shared states.
5. **Cross-Region EKS data:** EBS snapshots are regional. Velero metadata in S3 does not make a snapshot restorable in Singapore. Snapshot-copy automation and/or pgBackRest restore from a replicated Singapore repository must be tested explicitly.
6. **Backup authority:** Avoid overlapping RDS automated/PITR and AWS Backup schedules without intent. AWS documents overlap and duplicate storage/lineage considerations. Choose native RDS recovery as the primary mechanism and a narrow AWS Backup policy for demonstration.

### Strong recommendations

- Keep Mumbai/Singapore. Both support the core services and cross-Region backup features; the separation is credible. Re-check account quotas and exact add-on availability before each apply. Singapore may cost more and is geographically distant, but no change is justified now.
- Treat primary EKS as continuously active during project and demonstration windows. Even an idle standard-support EKS cluster is currently $0.10 per hour before nodes and storage, so the approved cost fallback is to destroy/recreate it outside those windows if measured spend is unacceptable. DR EKS remains absent until a drill/disaster.
- Use a single small, self-managed NAT instance in the primary public subnet as the cost-first lab choice for private EKS nodes. Build it from a current Amazon Linux 2023 image, require IMDSv2, disable source/destination checking, allow no inbound administration, and manage it as replaceable infrastructure. It is a single-AZ dependency with limited throughput and requires patching, so one managed NAT Gateway remains the fallback and production upgrade. Keep the free S3 gateway endpoint so S3/ECR layer traffic bypasses NAT.
- Retain the proposed eight subnets per Region for the first implementation because the separation makes ownership and routing easy to teach. Consolidating EC2 and EKS into two shared workload subnets would reduce objects but not meaningful hourly cost; approve that simplification separately if desired.
- Use one state bucket with versioning, Block Public Access, SSE, TLS-only policy, object-prefix IAM controls, and S3 native lockfiles. HashiCorp now marks DynamoDB locking deprecated.
- Use AWS-managed encryption keys initially where they satisfy cross-Region copy requirements. Customer-managed KMS keys add recurring cost and policy complexity; introduce them only where copy semantics or control objectives require them.
- Use `terraform_remote_state` only for non-sensitive, stable shared outputs. It grants consumers access to the whole state object even though only outputs are displayed. Separate state prefixes/roles and never output secrets.
- Use ALB alias records with `evaluate_target_health` where suitable and a manual workflow approval for regional cutover.

### Optional enhancements

- Add AWS Budget alerts before infrastructure, a cost-anomaly monitor if credits permit, and an inventory report for resources whose `Expiration` tag has passed.
- Add snapshot restore testing before full drills.
- Add DNSSEC later; it introduces KMS use and operational delegation work.
- Use Spot nodes for stateless EKS capacity after recovery behavior is stable; keep PostgreSQL scheduling deliberate.

### Future production improvements

- Multi-AZ RDS, at least two active application instances, one NAT Gateway per AZ, and redundant monitoring outside the workload failure domain.
- Cross-account immutable backup vaults, tighter KMS separation, centralized security logging, and AWS Organizations controls.
- Warm standby or active/passive data replication if business RTO is shorter than several hours.
- Managed database/operator architecture instead of single-replica PostgreSQL in Kubernetes.

## Lab implementation versus production upgrade

| Concern | Lab implementation | Production upgrade |
|---|---|---|
| Regional DR | Backup-and-restore, manually activated | Warm standby or automated orchestration with approvals |
| AZ recovery | Spare subnet capacity; restore/recreate | Active compute across AZs and Multi-AZ database |
| Egress | One temporary/single NAT or approved lab alternative | NAT per AZ and/or deliberately selected endpoints |
| Kubernetes database | One StatefulSet replica, EBS, pgBackRest | HA database operator or managed database |
| Monitoring | Lightweight in-cluster stack plus AWS external signal | Independent centralized monitoring and log archive |
| Backups | Same account, cross-Region | Cross-account, immutable, routinely restored |

## Ownership

No two states may manage the same resource. Platform owns bootstrap, global/shared, regional networking, and the shared contract. The EKS owner manages EKS and its DNS records. collaborator manages EC2/RDS/AWS Backup for that application and its DNS records. Details are in [shared-infrastructure-contract.md](shared-infrastructure-contract.md).

## Proposed final repository tree

```text
.
|-- README.md
|-- Makefile                         # later, command wrappers only
|-- .editorconfig
|-- .gitignore
|-- .github/
|   |-- CODEOWNERS
|   `-- workflows/                   # later; validation first, applies gated
|-- docs/
|   |-- architecture.md
|   |-- architecture/overview.mmd
|   |-- networking.md
|   |-- dr-strategy.md
|   |-- security.md
|   |-- cost-plan.md
|   |-- rpo-rto.md
|   |-- shared-infrastructure-contract.md
|   |-- terraform-conventions.md
|   |-- resource-naming.md
|   |-- collaboration.md
|   |-- collaborator-onboarding.md
|   |-- local-development.md
|   |-- implementation-plan.md
|   `-- runbooks/                    # added in the relevant implementation phases
|-- terraform/
|   |-- bootstrap/
|   |-- modules/
|   `-- environments/
|       |-- global/shared/
|       |-- primary/{shared,eks,ec2}/
|       `-- dr/{shared,eks,ec2}/
|-- kubernetes/{base,overlays}/
|-- applications/{eks-app,ec2-app}/
`-- scripts/{validate,backup,restore,failover,failback,cleanup}/
```

Empty implementation directories are intentionally not created during documentation phase.

## Decisions awaiting approval

1. Confirm the final NAT instance size after current Mumbai pricing and expected traffic are calculated in Phase 2; fall back to one NAT Gateway if the instance proves unreliable.
2. Provide Gokul's GitHub username, Owner/CostCenter tags, notification email, and an agreed monthly budget before implementation.
3. Confirm whether the GitHub repository is public or private because ruleset availability depends on the GitHub plan.

## Approved decisions recorded 2026-08-07

- Retain eight subnets per Region.
- Add `bootstrap` and `global/shared` Terraform state roots.
- Primary EKS is active during project/demonstration windows, with an approved destroy/recreate fallback outside those windows if cost is excessive. DR EKS is created only for a drill/disaster; it is not a running warm standby.
- GitHub owner is `Elzabeth-L`; repository target is `Elzabeth-L/Disaster-Recovery`.
- Use AWS-managed encryption keys/SSE-S3 initially. Store application/database credentials in AWS Secrets Manager where runtime integration is needed; avoid customer-managed KMS keys until a copy/control requirement justifies their recurring cost.
