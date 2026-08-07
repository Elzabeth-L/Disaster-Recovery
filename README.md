# Disaster Recovery Project

Documentation-first design for a cost-conscious AWS disaster recovery lab covering an AWS-native EC2/RDS application and an EKS/PostgreSQL application.

No AWS infrastructure has been applied in the current phase. The Phase 1 Terraform bootstrap is ready, and implementation will continue one approved phase at a time. Start with [the architecture](docs/architecture.md), [cost plan](docs/cost-plan.md), and [implementation plan](docs/implementation-plan.md).

## Current status

- Architecture and ownership model: proposed
- Git repository: initial documentation and Phase 1 bootstrap commit published to `main`
- Local CODEOWNERS: prepared for `@Elzabeth-L` (platform/EKS) and `@gokulk18` (EC2/RDS)
- Remote `main` protection: active; PRs, administrator enforcement, linear history, conversation resolution, and force-push/deletion blocking enabled. One approval and CODEOWNER review will be enabled after `@gokulk18` accepts the collaborator invitation.
- Phase 1 backend: code validated; plan is `7 add / 0 change / 0 destroy`; awaiting apply approval
- AWS resources created: none
- Terraform code: Phase 1 S3 state-backend bootstrap prepared and validated; Kubernetes code: none
- GoDaddy settings changed: none; GitHub `main` branch protection configured
- Next gate: explicit instruction `Approved. Apply Phase 1.`

## Core intent

- Primary Region: `ap-south-1` (Mumbai)
- DR Region: `ap-southeast-1` (Singapore)
- Strategy: cross-Region backup-and-restore with pilot-light networking
- DNS delegation: `dr.vaultrix.in` from GoDaddy to Route 53
- Independent Terraform states and ownership for shared, EKS, and EC2 work
- Manual disaster declaration and cost-controlled DR activation
