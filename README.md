# Disaster Recovery Project

Documentation-first design for a cost-conscious AWS disaster recovery lab covering an AWS-native EC2/RDS application and an EKS/PostgreSQL application.

Phase 1 is complete: the protected Terraform S3 state backend is deployed and its bootstrap state is stored remotely. Implementation will continue one approved phase at a time. Start with [the architecture](docs/architecture.md), [cost plan](docs/cost-plan.md), and [implementation plan](docs/implementation-plan.md).

## Current status

- Architecture and ownership model: proposed
- Git repository: initial documentation and Phase 1 bootstrap commit published to `main`
- Local CODEOWNERS: prepared for `@Elzabeth-L` (platform/EKS) and `@gokulk18` (EC2/RDS)
- Remote `main` protection: active; one approval, CODEOWNER review, stale-review dismissal, last-pusher separation, administrator enforcement, linear history, conversation resolution, and force-push/deletion blocking enabled.
- Phase 1 backend: applied successfully; `7 added / 0 changed / 0 destroyed`; bootstrap state migrated to S3
- Phase 2 primary network: code and plan prepared; `41 add / 0 change / 0 destroy`; no Phase 2 apply
- AWS resources created: one S3 bucket plus six bucket security/retention controls in `ap-south-1`
- Terraform code: Phase 1 S3 state-backend bootstrap deployed and validated; Kubernetes code: none
- GoDaddy settings changed: none; GitHub `main` branch protection configured
- Next gate: Gokul reviews the Phase 2 PR; after merge, regenerate the protected-main plan and separately approve Phase 2 apply

## Core intent

- Primary Region: `ap-south-1` (Mumbai)
- DR Region: `ap-southeast-1` (Singapore)
- Strategy: cross-Region backup-and-restore with pilot-light networking
- DNS delegation: `dr.vaultrix.in` from GoDaddy to Route 53
- Independent Terraform states and ownership for shared, EKS, and EC2 work
- Manual disaster declaration and cost-controlled DR activation
