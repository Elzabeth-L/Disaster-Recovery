# Master Implementation Prompt — Disaster Recovery Project

You are acting as the senior cloud/platform engineer for a two-person AWS Disaster Recovery project.

Do **not** immediately start creating Terraform, Kubernetes manifests, GitHub Actions workflows, application code, or AWS resources.

Your first responsibility is to inspect the repository, understand this complete architecture specification, identify contradictions or risks, propose improvements, and produce detailed project documentation and an implementation plan.

Only after I explicitly approve the documentation and implementation plan may you begin implementation.


---
everything should be compatible in freetier plan

as of now there is no repo, so go through this plan first to create the implementation plan and the repo.

also regarding the feature branches, you can reduce the number of feature branches lsited here and group them together.

also if there are any infra or resource changes for app1 - that is collaborators app, it must be compatible because hell be making decisions for that. dont just go strictly with what i have given here as part of his application .

go with terraform not opentofu.
---

# 1. Project overview

We are building a production-inspired, cost-conscious Disaster Recovery platform on AWS.

The project has two independent application tracks:

1. AWS-native disaster recovery application

   * EC2
   * Application Load Balancer
   * RDS PostgreSQL
   * AMI recovery
   * EBS snapshots
   * AWS Backup
   * CloudWatch
   * Route 53

2. Kubernetes/open-source disaster recovery application

   * Amazon EKS
   * Kubernetes application
   * PostgreSQL StatefulSet
   * EBS persistent storage
   * Velero
   * pgBackRest
   * Prometheus
   * Grafana
   * Alertmanager
   * Route 53

Both applications share a common infrastructure/platform layer.

The purpose of the project is not merely to deploy two applications.

The project must demonstrate:

* Infrastructure recovery
* Compute recovery
* Database recovery
* Kubernetes recovery
* Persistent-volume recovery
* Backup and restore
* Cross-AZ recovery
* Cross-Region disaster recovery
* DNS failover
* Monitoring and alerting
* RPO/RTO measurement
* Recovery runbooks
* Failover and failback
* Cost-aware architecture
* Infrastructure as Code
* Git collaboration between two engineers

---

# 2. Team structure

There are two engineers.

## Engineer 1 — project/platform/EKS owner

I will own:

* Repository architecture
* Shared Terraform infrastructure
* Terraform conventions
* Primary and DR VPCs
* Subnets
* Route tables
* Internet Gateways
* S3 Gateway Endpoints
* Shared Route 53 hosted zone
* DNS delegation design
* Terraform backend
* GitHub Actions OIDC foundation
* Shared IAM foundations
* Shared tagging/naming standards
* Cost controls
* EKS infrastructure
* EKS worker nodes
* EBS CSI driver
* Kubernetes application
* PostgreSQL StatefulSet
* Velero
* pgBackRest
* Prometheus
* Grafana
* Alertmanager
* EKS disaster-recovery workflows
* Documentation structure
* Shared DR orchestration design

## Engineer 2 — collaborator — EC2/RDS owner

collaborator will later own:

* EC2 application
* EC2 Launch Template
* EC2 Auto Scaling Group where applicable
* EC2 Application Load Balancer
* EC2 Target Groups
* EC2 Security Groups
* Golden AMI process
* EBS snapshot recovery
* RDS PostgreSQL
* RDS subnet group
* RDS parameter/security configuration
* RDS backups
* AWS Backup
* CloudWatch monitoring for the EC2 application
* EC2-specific Route 53 records
* EC2-specific GitHub Actions workflows
* EC2 disaster recovery procedures
* EC2 failback procedures

The repository and shared infrastructure must be designed so that collaborator can safely work independently without modifying or accidentally destroying the EKS or shared platform stack.

---

# 3. Collaboration model

This is a single GitHub monorepo.

Do not design separate repositories.

The intended workflow is:

1. Shared foundation is designed first.
2. Shared infrastructure is implemented first.
3. Shared changes are merged into `main`.
4. Both engineers pull the updated `main`.
5. EKS and EC2 development continue independently on feature branches.
6. Pull requests run validation pipelines.
7. Changes merge into `main` only after successful CI and review.
8. DR integration testing happens after both stacks are functional.

Do not design a workflow where two long-lived branches are developed independently for weeks and merged only at the end.

Prefer small feature branches and frequent integration.

Suggested branch model:

* `main`
* `feature/shared-network`
* `feature/shared-route53`
* `feature/shared-iam`
* `feature/eks-cluster`
* `feature/eks-storage`
* `feature/eks-velero`
* `feature/eks-monitoring`
* `feature/eks-dr`
* `feature/ec2-base`
* `feature/rds`
* `feature/aws-backup`
* `feature/ec2-monitoring`
* `feature/ec2-dr`

No direct pushes to `main`.

---

# 4. Domain and DNS

I already own this domain through GoDaddy:

`vaultrix.in`

Do not transfer the domain away from GoDaddy.

GoDaddy remains the domain registrar and authoritative DNS provider for the existing root domain unless delegation requires otherwise.

We want to delegate only a DR/project subdomain to Route 53.

Preferred delegated subdomain:

`dr.vaultrix.in`

Create/document a Route 53 hosted zone for:

`dr.vaultrix.in`

GoDaddy should contain NS delegation records pointing `dr.vaultrix.in` to the Route 53 name servers.

Application hostnames should initially be:

* `ec2.dr.vaultrix.in`
* `eks.dr.vaultrix.in`

Potential diagnostic/internal names may include:

* `ec2-primary.dr.vaultrix.in`
* `ec2-dr.dr.vaultrix.in`
* `eks-primary.dr.vaultrix.in`
* `eks-dr.dr.vaultrix.in`

The public application records should ultimately support Route 53 failover routing.

Do not let the EC2 stack or EKS stack independently create the Route 53 hosted zone.

The shared stack owns the hosted zone.

The application stacks may create only their own records.

For example:

Shared:

* `dr.vaultrix.in` hosted zone

EC2 stack:

* `ec2.dr.vaultrix.in`

EKS stack:

* `eks.dr.vaultrix.in`

---

# 5. Disaster Recovery strategy

This project is intentionally cost-conscious.

The selected model is:

**Cross-Region backup-and-restore with pilot-light networking**

It may also be described in documentation as:

**Cost-optimized pilot-light hybrid**

Do not describe it as active-active.

Do not describe it as warm standby.

Do not describe the primary deployment as full Multi-AZ high availability if only one set of compute resources is actively running.

The architecture has:

## Within the primary Region

Cost-optimized cross-AZ recovery capability.

AZ-1 contains the primary active workloads.

AZ-2 contains subnet/network capacity and recovery capability but does not necessarily run duplicate compute continuously.

This reduces cost but means an AZ failure may involve recovery time.

## Across Regions

The DR Region contains:

* VPC
* Subnets
* Route tables
* Internet Gateway where justified
* Security group definitions
* S3 backup/replica storage
* Copied AMIs where configured
* Copied snapshots where configured
* Terraform configuration
* Recovery runbooks

The DR Region should normally NOT contain continuously running:

* EC2 recovery instances
* EKS cluster
* EKS worker nodes
* RDS recovery database
* Recovery ALBs
* NAT Gateways

These should be created only during controlled DR drills or an actual declared disaster.

This is specifically intended to reduce cost.

---

# 6. Regions

Current proposed architecture:

Primary Region:
`ap-south-1`

DR Region:
`ap-southeast-1`

Before implementation, confirm that these are sensible for:

* service availability
* cost
* backup-copy support
* EKS support
* RDS support
* Route 53 integration
* AMI copying
* EBS snapshot copying
* latency considerations
* project requirements

If you believe another DR Region would be significantly better, document the recommendation and justification.

Do NOT silently change Regions.

---

# 7. Network architecture

Use separate VPCs because VPCs are Region-scoped.

## Primary VPC

CIDR:

`10.10.0.0/16`

Two Availability Zones.

Logical subnet plan:

AZ-1:

* Public: `10.10.1.0/24`
* EC2 private: `10.10.11.0/24`
* EKS private: `10.10.21.0/24`
* Database private: `10.10.31.0/24`

AZ-2:

* Public: `10.10.2.0/24`
* EC2 private: `10.10.12.0/24`
* EKS private: `10.10.22.0/24`
* Database private: `10.10.32.0/24`

## DR VPC

CIDR:

`10.20.0.0/16`

Two Availability Zones.

AZ-1:

* Public: `10.20.1.0/24`
* EC2 private: `10.20.11.0/24`
* EKS private: `10.20.21.0/24`
* Database private: `10.20.31.0/24`

AZ-2:

* Public: `10.20.2.0/24`
* EC2 private: `10.20.12.0/24`
* EKS private: `10.20.22.0/24`
* Database private: `10.20.32.0/24`

The DR network must match the primary network **functionally**, but it does not need identical CIDRs or AZ names.

Do not assume `ap-south-1a` maps physically to `ap-southeast-1a`.

---

# 8. Network resource placement

Public subnets:

* Application Load Balancers
* Internet-facing resources only when justified

EC2 private subnets:

* EC2 application compute

EKS private subnets:

* EKS worker nodes

Database private subnets:

* RDS PostgreSQL

EBS is not a subnet resource.

EBS volumes are AZ-scoped and attach to compute within the corresponding AZ.

---

# 9. Internet connectivity and VPC endpoints

Avoid NAT Gateway initially because cost is a major constraint.

Use an S3 Gateway VPC Endpoint.

This should support private access to S3 for:

* Velero
* pgBackRest
* EC2 backup scripts if required
* Application S3 access
* Backup repositories

Do not automatically create large numbers of Interface VPC Endpoints.

Interface endpoints such as:

* ECR API
* ECR Docker
* STS
* CloudWatch Logs
* Systems Manager
* Secrets Manager

may introduce recurring costs.

During planning, evaluate:

* S3 Gateway Endpoint
* temporary NAT for provisioning
* public-node lab configuration
* minimal interface endpoints

Recommend the lowest-cost architecture that remains reasonably secure and demonstrable.

Document clearly where the lab architecture differs from the ideal production architecture.

---

# 10. Security principles

The architecture must follow these rules.

* RDS must not be publicly accessible.
* Database subnets must have no direct Internet Gateway route.
* Do not use `0.0.0.0/0` for SSH.
* Prefer SSM Session Manager if practical.
* Do not commit AWS credentials.
* Do not commit kubeconfig.
* Do not commit database credentials.
* Do not commit Terraform state.
* Do not store long-lived AWS access keys in GitHub.
* GitHub Actions should use AWS OIDC.
* IAM roles should be least privilege.
* EC2 and EKS deployments should use separate security groups.
* Shared security groups should not be modified by both application stacks.
* S3 Block Public Access should be enabled.
* Encryption at rest should be enabled where practical.
* S3 backup buckets should be versioned.
* Secrets should be handled through an appropriate mechanism.
* Security Groups should reference other security groups where practical rather than broad CIDR rules.

---

# 11. Application 1 — EC2 / AWS-native DR

collaborator will implement this later.

Do not implement this application during my initial shared/EKS phase unless a shared dependency requires it.

Target architecture:

Internet
→ Route 53
→ EC2 application ALB
→ EC2 application
→ RDS PostgreSQL

Optional application objects:
→ S3

Recovery technologies:

* Golden AMI
* EBS snapshots
* RDS automated backups
* RDS PITR where supported
* Manual RDS snapshot before DR tests
* AWS Backup for learning/demonstration
* CloudWatch
* SNS notifications
* Route 53 failover

AWS DRS is deliberately excluded from the main implementation because of cost.

Document AWS DRS only as an alternative architecture.

Do not implement it unless explicitly requested later.

Suggested initial backup policy:

* Golden AMI: weekly or pre-release
* EBS mutable data snapshot: daily
* EBS snapshot retention: approximately 7 days for lab
* RDS automated backups: enabled
* RDS retention: approximately 7 days for lab
* Manual RDS snapshot: before regional DR drills

These values should remain configurable.

Do not hard-code assumptions if Terraform variables are appropriate.

---

# 12. Application 2 — EKS / open-source DR

This is my application and will be implemented after shared infrastructure approval.

Target architecture:

Internet
→ Route 53
→ AWS Load Balancer Controller / ALB
→ EKS
→ application Pods

Database:

PostgreSQL StatefulSet
→ PersistentVolumeClaim
→ EBS gp3 using EBS CSI

Do NOT use PostgreSQL inside an ordinary ephemeral Pod.

Do NOT use EFS as PostgreSQL storage.

EFS is excluded unless we later introduce a legitimate ReadWriteMany shared-file use case.

---

# 13. EKS DR tool selection

Use:

* Velero
* pgBackRest
* Terraform
* Prometheus
* Grafana
* Alertmanager

Do NOT initially use:

* Patroni
* Restic as a standalone duplicate backup system
* Argo CD
* Chaos Mesh
* Uptime Kuma
* EFS for PostgreSQL
* AWS DRS

Reasons:

Patroni:

* primarily HA
* requires more database replicas
* increases cost and complexity

Restic:

* unnecessary duplication unless Velero file-system backup is specifically required

Argo CD:

* CD/GitOps is not currently required

Chaos Mesh:

* optional later after DR works reliably

Uptime Kuma:

* Route 53 + CloudWatch provide the external failure signal
* monitoring running inside the failed cluster cannot detect total-cluster failure reliably

---

# 14. EKS recovery layers

The EKS design must explicitly separate four recovery layers.

## Layer 1 — Infrastructure

Terraform recreates:

* VPC dependencies
* EKS
* Managed Node Groups
* IAM
* EBS CSI
* AWS Load Balancer Controller
* required add-ons

## Layer 2 — Desired Kubernetes state

Version-controlled Kubernetes manifests, Helm charts, or Kustomize configuration recreate:

* Namespaces
* Deployments
* StatefulSets
* Services
* Ingress
* ConfigMaps where appropriate

No Argo CD is required.

## Layer 3 — Kubernetes backup

Velero protects:

* Kubernetes resources
* selected namespaces
* PVC metadata
* CSI-backed snapshots where supported

## Layer 4 — Database data

pgBackRest protects PostgreSQL independently.

Target concept:

* weekly full backup
* daily differential backup
* continuous WAL archiving
* S3 repository

These schedules must be configurable.

Do not assume Velero backup alone provides database consistency.

---

# 15. Kubernetes PostgreSQL recovery

PostgreSQL runs as a StatefulSet.

Storage:

PVC
→ EBS gp3

The design must acknowledge that EBS is AZ-scoped.

If an EBS volume exists in AZ-1 and AZ-1 fails:

* it cannot simply be attached to a node in AZ-2
* recovery may involve snapshot restoration into AZ-2
* PostgreSQL may require pgBackRest recovery
* downtime is expected

This is recovery-oriented architecture, not instant database HA.

Document this limitation.

---

# 16. Monitoring architecture

## Shared/external

Route 53 and CloudWatch should provide external health monitoring where possible.

Monitoring inside EKS alone is not sufficient because the monitoring stack disappears if the entire cluster fails.

## EC2 application

collaborator will later implement:

* CloudWatch metrics
* CloudWatch Agent where useful
* ALB health
* RDS alarms
* application errors
* backup-job failures
* SNS notifications

## EKS application

Implement later:

* Prometheus
* Grafana
* Alertmanager
* kube-state-metrics
* node exporter where justified
* PostgreSQL exporter
* Velero metrics

Keep resource requests/limits conservative because cost is critical.

Avoid deploying an unnecessarily large kube-prometheus stack configuration.

---

# 17. Terraform architecture

Use reusable Terraform modules and independent root modules.

Suggested repository layout:

project-root/
├── README.md
├── Makefile
├── .gitignore
├── .editorconfig
│
├── docs/
│   ├── architecture/
│   ├── architecture.md
│   ├── networking.md
│   ├── dr-strategy.md
│   ├── rpo-rto.md
│   ├── cost-plan.md
│   ├── security.md
│   ├── shared-infrastructure-contract.md
│   ├── terraform-conventions.md
│   ├── resource-naming.md
│   ├── collaboration.md
│   ├── local-development.md
│   └── runbooks/
│       ├── eks-failover.md
│       ├── eks-failback.md
│       ├── ec2-failover.md
│       ├── ec2-failback.md
│       └── full-dr-drill.md
│
├── terraform/
│   ├── modules/
│   │   ├── networking/
│   │   ├── route53/
│   │   ├── s3-gateway-endpoint/
│   │   ├── github-oidc/
│   │   ├── kms/
│   │   ├── shared-iam/
│   │   ├── eks/
│   │   ├── eks-node-group/
│   │   ├── ec2/
│   │   ├── alb/
│   │   ├── rds/
│   │   └── aws-backup/
│   │
│   └── environments/
│       ├── primary/
│       │   ├── shared/
│       │   ├── eks/
│       │   └── ec2/
│       │
│       └── dr/
│           ├── shared/
│           ├── eks/
│           └── ec2/
│
├── kubernetes/
│   ├── base/
│   ├── namespaces/
│   ├── application/
│   ├── postgres/
│   ├── velero/
│   ├── pgbackrest/
│   └── monitoring/
│
├── applications/
│   ├── eks-app/
│   └── ec2-app/
│
├── scripts/
│   ├── validate/
│   ├── backup/
│   ├── restore/
│   ├── failover/
│   ├── failback/
│   └── cleanup/
│
└── .github/
├── CODEOWNERS
└── workflows/
├── terraform-pr-check.yml
├── terraform-shared.yml
├── terraform-eks.yml
├── terraform-ec2.yml
├── eks-deploy.yml
├── eks-dr-test.yml
├── ec2-deploy.yml
├── ec2-dr-test.yml
└── full-dr-test.yml

You may recommend modifications to this structure if there is a strong engineering justification.

Do not modify it silently.

---

# 18. Terraform state separation

This is mandatory.

Do not put the complete platform into one Terraform state.

At minimum separate:

* primary/shared
* primary/eks
* primary/ec2
* dr/shared
* dr/eks
* dr/ec2

Conceptual state keys:

* `primary/shared/terraform.tfstate`
* `primary/eks/terraform.tfstate`
* `primary/ec2/terraform.tfstate`
* `dr/shared/terraform.tfstate`
* `dr/eks/terraform.tfstate`
* `dr/ec2/terraform.tfstate`

Use an S3 backend.

Research and recommend the currently preferred Terraform/OpenTofu-compatible state-locking mechanism.

Do not assume an outdated locking pattern without checking the Terraform version selected.

State encryption and bucket versioning should be enabled.

State bucket access must be tightly controlled.

---

# 19. Shared infrastructure contract

The shared stack must expose stable outputs for application stacks.

Expected outputs include at least:

* `primary_vpc_id`
* `dr_vpc_id`
* `public_subnet_ids`
* `ec2_private_subnet_ids`
* `eks_private_subnet_ids`
* `database_subnet_ids`
* `route53_zone_id`
* `route53_zone_name`
* `s3_gateway_endpoint_id`
* `primary_region`
* `dr_region`

If primary and DR stacks are separate, name outputs clearly enough to avoid ambiguity.

Application stacks consume shared infrastructure using remote-state outputs or another clearly documented mechanism.

collaborator should not re-run shared networking modules.

Example principle:

Reusable Terraform module:
creates resources.

Shared state output:
allows another stack to consume resources already created.

Treat the shared outputs as an API contract.

Document the contract thoroughly.

---

# 20. Shared vs application ownership

Shared stack owns:

* Primary VPC
* DR VPC
* Public/private subnet architecture
* Route tables
* Internet Gateway
* S3 Gateway Endpoint
* Route 53 hosted zone
* GitHub OIDC provider
* shared IAM foundations
* shared tags/naming
* Terraform backend/bootstrap resources where appropriate

EC2 stack owns:

* EC2 ALB
* EC2 Target Group
* Launch Template
* ASG/EC2
* EC2 Security Groups
* RDS
* RDS Security Groups
* AWS Backup resources
* EC2 CloudWatch alarms
* EC2 DNS records

EKS stack owns:

* EKS
* node groups
* EKS IAM roles
* AWS Load Balancer Controller
* EBS CSI
* Kubernetes objects
* PostgreSQL StatefulSet
* EBS PVC
* Velero
* pgBackRest
* Prometheus
* Grafana
* Alertmanager
* EKS ALB
* EKS DNS records

Never allow two independent Terraform states to own the same AWS resource.

---

# 21. Naming standard

Develop a consistent naming standard during documentation.

Suggested pattern:

`vaultrix-dr-<environment>-<component>`

Examples:

* `vaultrix-dr-primary-vpc`
* `vaultrix-dr-primary-eks`
* `vaultrix-dr-primary-ec2`
* `vaultrix-dr-primary-rds`
* `vaultrix-dr-dr-vpc`

If you recommend a cleaner naming convention, explain it before changing it.

Tags should include at minimum:

* `Project = vaultrix-dr`
* `Environment = primary | dr`
* `Application = shared | eks | ec2`
* `ManagedBy = terraform`
* `Owner`
* `CostCenter` or equivalent project tag if useful
* `Expiration` or cleanup indicator for temporary DR resources if practical

---

# 22. GitHub Actions

Use GitHub Actions.

Do not place static AWS access keys in GitHub Secrets.

Use GitHub OIDC.

Prefer separate AWS IAM roles for:

* shared infrastructure
* EKS infrastructure
* EC2 infrastructure

Conceptually:

* `github-shared-role`
* `github-eks-role`
* `github-ec2-role`

Design least-privilege policies.

Do not use AdministratorAccess unless there is no reasonable alternative, and if temporary broad access is required during initial learning, flag it explicitly as technical debt.

---

# 23. Pipeline architecture

Use path-filtered workflows.

Shared workflow triggers only for shared infrastructure paths.

EKS workflow triggers only for:

* EKS Terraform
* Kubernetes
* EKS application changes

EC2 workflow triggers only for:

* EC2 Terraform
* RDS
* AWS Backup
* EC2 application

A Kubernetes change must not trigger EC2 deployment.

An EC2 application change must not modify EKS.

PR checks should include as applicable:

* `terraform fmt -check`
* `terraform init`
* `terraform validate`
* TFLint
* Checkov or tfsec
* Terraform plan
* YAML validation
* Kubernetes schema validation where practical
* Helm lint where applicable

Do not automatically apply DR infrastructure on every merge.

DR deployments should use manual workflow triggering such as `workflow_dispatch`, with explicit confirmation/approval where possible.

This is because creating:

* EKS
* RDS
* ALB
* EC2

in the DR Region can create unexpected costs.

---

# 24. GitHub branch protection

Document how I should configure:

`main`

with:

* no direct pushes
* pull requests required
* required CI checks
* at least one review where practical
* branch up-to-date requirement if appropriate

Also propose a CODEOWNERS file.

Conceptually:

Shared infrastructure:
both engineers / platform owner approval

EKS:
me

EC2/RDS:
collaborator

Do not invent GitHub usernames.

Use placeholders until usernames are provided.

---

# 25. collaborator onboarding requirements

Once the shared infrastructure is completed, I need a complete handoff package for collaborator.

Create a dedicated document:

`docs/collaborator-onboarding.md`

It must explain:

## Repository access

How I should invite collaborator as a GitHub repository collaborator.

Do not require sharing my GitHub credentials.

Explain:

* collaborator invitation
* minimum repository permission required
* branch protection implications
* PR workflow

## Local prerequisites

List required tools and versions, for example:

* Git
* Terraform/OpenTofu
* AWS CLI
* Docker if required
* GitHub CLI optionally
* jq
* make if used

## AWS authentication

Explain how his local environment should authenticate safely.

Do not share my IAM access keys.

Recommend an IAM/SSO-based or otherwise safe mechanism suitable for this lab.

## Git workflow

Give exact workflow examples:

* clone
* checkout main
* pull
* create feature branch
* commit
* push
* open PR
* update branch
* resolve conflicts

## Terraform contract

Explain exactly which shared outputs he may use.

Include examples showing how the EC2 stack consumes remote-state outputs.

## Resources he owns

Explicitly list EC2/RDS/AWS Backup resources.

## Resources he must not create

Explicitly list:

* VPC
* shared subnets
* Route 53 hosted zone
* S3 Gateway Endpoint
* GitHub OIDC provider
* shared backend
* shared networking

## DNS

Explain that:

* hosted zone is shared
* he owns only `ec2.dr.vaultrix.in` records

## State

Explain that his resources live only in:

* `primary/ec2`
* `dr/ec2`

state.

## CI

Explain:

* which workflows his changes trigger
* expected checks
* how Terraform plan is reviewed
* when apply occurs

## Cost

Explain how to avoid accidentally launching DR infrastructure.

This document must be complete enough that I can give it directly to collaborator.

---

# 26. Cost constraints

Cost is a primary architectural constraint.

The project should be designed to minimize recurring charges.

Important cost risks include:

* EKS control-plane charges
* EKS worker nodes
* NAT Gateway
* Interface VPC Endpoints
* ALBs
* RDS
* EC2
* EBS
* snapshots
* cross-Region data transfer
* S3 CRR
* Route 53 hosted zones
* Route 53 health checks
* forgotten DR resources

During planning, create:

`docs/cost-plan.md`

It must categorize every significant service as:

* always running
* temporary
* backup/storage only
* created only during DR drill
* optional

Also provide:

* approximate cost-risk level: low/medium/high
* cost-saving alternative
* functionality lost by choosing the cheaper option

Do not claim that the complete architecture is permanently free-tier eligible.

Clearly distinguish:

* free/no-hourly-cost networking primitives
* AWS Free Tier/credit-dependent resources
* always-billed services

---

# 27. Backup strategy

## EC2 application

Initial target:

Golden AMI:

* weekly or pre-release

EBS mutable volume:

* daily snapshot
* approximately 7-day retention

RDS:

* automated backup
* PITR
* approximately 7-day retention
* manual snapshot before DR drill

AWS Backup:

* use for AWS-native backup learning
* avoid excessive duplication

## EKS

Velero:

* scheduled Kubernetes backup
* CSI volume snapshot where appropriate
* S3 object store

pgBackRest:

* weekly full
* daily differential
* continuous WAL

S3:

* versioning
* encryption
* lifecycle rules

Cross-Region replication:

* selective
* cost-controlled

Do not replicate unnecessary monitoring/log/temp data.

---

# 28. DR workflow

Document regional failover as:

1. Detect failure.
2. Alert.
3. Human declares disaster.
4. Trigger DR workflow manually.
5. Terraform creates required DR compute.
6. Restore EC2 application.
7. Restore RDS.
8. Create EKS.
9. Install required add-ons.
10. Restore Kubernetes resources using Velero.
11. Restore PostgreSQL/PVC.
12. Validate data.
13. Run smoke tests.
14. Confirm both applications healthy.
15. Perform Route 53 failover.
16. Monitor.
17. Measure RTO.
18. Measure RPO.
19. Document result.

Do NOT automatically create the entire DR Region from a single health-check failure.

Transient outages should not create expensive infrastructure automatically.

---

# 29. Failback

Create a documented failback process.

It must address:

* rebuilding primary
* determining authoritative database
* stopping or controlling writes
* synchronizing data back
* validating primary
* Route 53 switchback
* avoiding split brain
* cleanup of DR compute
* preserving backup evidence

Failback is part of the project definition of done.

---

# 30. DR scenarios

Documentation should eventually include tests for:

EC2:

* process failure
* instance failure
* EBS data loss
* AMI recovery
* RDS recovery
* regional restore

EKS:

* Pod deletion
* worker-node failure
* namespace deletion
* PVC deletion
* PostgreSQL corruption
* EKS cluster recreation
* regional restore

Networking:

* primary endpoint unhealthy
* Route 53 failover

Do not intentionally create a real AWS Region outage.

Use controlled simulations.

---

# 31. RPO and RTO

Create:

`docs/rpo-rto.md`

Define initial target RPO/RTO values as project objectives rather than AWS guarantees.

Include separate objectives for:

* EC2 application
* RDS
* EKS application
* EKS PostgreSQL
* Kubernetes resources
* S3 objects

Also describe how actual RPO/RTO will be measured during DR tests.

---

# 32. Documentation-first requirement

THIS IS CRITICAL.

During your first response/work session:

DO NOT IMPLEMENT INFRASTRUCTURE.

DO NOT CREATE TERRAFORM RESOURCES.

DO NOT CREATE KUBERNETES RESOURCES.

DO NOT RUN TERRAFORM APPLY.

DO NOT CREATE AWS RESOURCES.

DO NOT CREATE DEPLOYMENT WORKFLOWS THAT CAN APPLY INFRASTRUCTURE.

First inspect the repository.

Then create/update ONLY documentation and planning artifacts.

The first phase should produce at minimum:

1. `docs/architecture.md`
2. `docs/networking.md`
3. `docs/dr-strategy.md`
4. `docs/security.md`
5. `docs/cost-plan.md`
6. `docs/rpo-rto.md`
7. `docs/shared-infrastructure-contract.md`
8. `docs/terraform-conventions.md`
9. `docs/resource-naming.md`
10. `docs/collaboration.md`
11. `docs/collaborator-onboarding.md`
12. `docs/local-development.md`
13. `docs/implementation-plan.md`
14. `docs/architecture/` diagram source if practical
15. Proposed repository tree

You may create README changes describing the planned project, but no executable infrastructure should be introduced yet.

---

# 33. Implementation plan requirements

`docs/implementation-plan.md` must divide implementation into explicit phases.

Recommended starting point:

## Phase 0 — Repository/bootstrap design

* repository layout
* `.gitignore`
* Terraform conventions
* versions
* linting strategy
* documentation
* ownership
* branch rules

## Phase 1 — Terraform backend/bootstrap

* backend bucket
* state versioning
* state encryption
* locking strategy
* bootstrap caveat

## Phase 2 — Shared primary networking

* primary VPC
* AZ selection
* subnets
* route tables
* IGW
* S3 Gateway Endpoint

## Phase 3 — Shared DR networking

* DR VPC
* matching subnet topology
* DR S3 access
* networking validation

## Combined Phases 4–5 — DNS, GitHub OIDC, and IAM

Deliver these together in the global/shared state:

* Route 53 hosted zone
* GoDaddy delegation instructions
* DNS validation
* GitHub OIDC provider
* shared role
* EKS role
* EC2 role

## Phase 6 — Merge shared foundation

* CI
* PR
* shared outputs
* contract freeze
* collaborator handoff

## Phase 7A — EKS implementation

My work.

## Phase 7B — EC2 implementation

collaborator's parallel work.

## Phase 8 — Backup configuration

Velero/pgBackRest and AWS Backup.

## Phase 9 — Monitoring

Prometheus/Grafana/Alertmanager and CloudWatch.

## Phase 10 — DR infrastructure automation

On-demand DR creation.

## Phase 11 — DNS failover

Route 53 failover records and validation.

## Phase 12 — DR drills

RPO/RTO measurement.

## Phase 13 — Failback

## Phase 14 — Cleanup/cost review

For every phase specify:

* objective
* resources
* files created
* dependencies
* owner
* expected cost impact
* tests
* acceptance criteria
* rollback/cleanup method

---

# 34. Architecture review requirement

Before implementation, evaluate the proposed architecture critically.

Create a section called:

`Architecture Review and Recommendations`

Categorize observations as:

* Required correction
* Strong recommendation
* Optional enhancement
* Future production improvement

Examples of questions you should evaluate:

* Is the subnet count unnecessarily large for this lab?
* Is separate EC2/EKS/private subnet separation worth the operational complexity?
* Is pre-creating the entire DR VPC justified?
* Is the S3 Gateway Endpoint sufficient?
* Would short-lived NAT be cheaper than interface endpoints?
* Should KMS be shared or separate?
* Is remote state the best shared-contract mechanism?
* What is the safest current Terraform state-locking approach?
* Should OpenTofu be preferred if full open-source licensing matters?
* Are any AWS services assumed to be free when they are not?
* Are any resources unavailable in the proposed Regions?
* Can any backup duplication be removed?
* Is the current DR terminology technically correct?
* Are any resources being placed in incorrect subnet types?
* Are there hidden cross-AZ/EBS constraints?
* Are there quota risks during DR?
* Are there IAM circular dependencies between bootstrap and CI?
* Should DNS failover be automated or manually approved?

Do not silently implement a recommendation.

Present the recommendation and wait for approval where it materially changes architecture.

---

# 35. Current technology versions

Before proposing implementation versions, determine the current stable and mutually compatible versions of:

* Terraform or OpenTofu
* AWS provider
* Kubernetes version supported by EKS
* Helm provider if used
* kubectl tooling expectations
* Velero
* pgBackRest
* Prometheus/Grafana chart versions where relevant
* AWS Load Balancer Controller
* EBS CSI driver

Pin versions.

Do not use `latest` indiscriminately.

Document why versions were chosen.

If internet access is unavailable, state that current versions need verification rather than inventing version numbers.

---

# 36. Coding principles for later implementation

Once approved:

* infrastructure must be idempotent
* avoid copy/paste between primary and DR where modules solve the problem
* modules should be reusable but not excessively abstract
* variables should have validation
* outputs should be documented
* provider aliases should be used appropriately for multi-Region resources
* no hard-coded account IDs
* no secrets in code
* no hard-coded AZ names unless intentionally configured
* locals should centralize naming/tags
* use `for_each` where it improves clarity
* avoid clever Terraform that reduces readability
* include useful descriptions/comments
* ensure destroy does not unexpectedly remove shared resources
* mark destructive actions clearly
* use lifecycle protection where genuinely useful, not everywhere

---

# 37. Cost safety mechanisms

Before any infrastructure implementation later, recommend mechanisms such as:

* AWS Budget
* budget alerts
* resource tagging
* lifecycle policies
* automatic expiry tags
* cleanup workflow
* manual DR apply
* Terraform plan review
* scheduled detection of forgotten resources if practical

A DR drill should end with a cleanup checklist.

DR compute should not remain running accidentally.

---

# 38. Definition of shared-foundation completion

The shared phase is complete only when:

* repository architecture is established
* documentation is approved
* primary shared networking works
* DR shared networking works
* Terraform backend works
* state separation is proven
* Route 53 hosted zone exists or is fully prepared
* GoDaddy delegation instructions are documented
* S3 Gateway Endpoint is validated
* GitHub OIDC design works
* shared outputs are stable
* validation pipeline succeeds
* architecture is documented
* cost controls exist
* collaborator onboarding guide exists
* collaborator can consume shared outputs without modifying shared resources

Only then should EC2 and EKS implementation proceed fully in parallel.

---

# 39. What I want you to do NOW

Start by inspecting the current repository.

Then respond with:

1. Current repository assessment.
2. Any conflicts between the existing repo and this architecture.
3. Architecture corrections you believe are required.
4. Cost concerns.
5. Security concerns.
6. Terraform architecture recommendations.
7. GitHub collaboration recommendations.
8. Proposed final repository tree.
9. Proposed shared Terraform output contract.
10. Proposed implementation phases.
11. Questions/blockers that genuinely prevent implementation.

Then create the documentation files described above.

Do NOT implement AWS resources yet.

Do NOT create Terraform resources yet.

Do NOT deploy anything.

Do NOT run `terraform apply`.

Do NOT create EKS.

Do NOT create EC2.

Do NOT create RDS.

Do NOT make changes to GoDaddy.

Do NOT configure GitHub repository permissions automatically.

Do NOT push or merge branches without my instruction.

After documentation is created, give me:

* a concise summary of the proposed architecture
* a list of files created/modified
* recommendations and corrections
* unresolved decisions
* expected cost risks
* the exact implementation sequence you propose

Then STOP.

Explicitly wait for me to approve the implementation plan.

Only after I say something equivalent to:

`Approved. Start Phase 1.`

may you begin writing infrastructure code.

Even after approval, implement one phase at a time.

At the end of each phase:

* run appropriate validation
* show files changed
* show validation results
* explain resources that would be created
* show cost implications
* state whether AWS resources were actually created
* wait for approval before moving to the next major phase unless I explicitly authorize multiple phases

---

# 40. Important design philosophy

This project should look like something two cloud/platform engineers could realistically maintain.

Optimize for:

1. Safety
2. Clear ownership
3. Recoverability
4. Low cost
5. Reproducibility
6. Observability
7. Collaboration
8. Learning value
9. Production-inspired design
10. Simplicity

Do not add technologies merely because they are popular.

Every tool or AWS service must have a clear purpose.

When a simpler solution achieves the project objective at lower cost, recommend it.

When the low-cost architecture differs from true production architecture, document both:

`Lab implementation`

and

`Production upgrade`

so the design remains technically honest.

The project is called the **Disaster Recovery Project**, and the existing domain is **vaultrix.in**.
