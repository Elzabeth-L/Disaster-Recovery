# Disaster Recovery Project

Documentation-first design for a cost-conscious AWS disaster recovery lab covering an AWS-native EC2/RDS application and an EKS/PostgreSQL application.

Phase 1 is complete: the protected Terraform S3 state backend is deployed and its bootstrap state is stored remotely. Implementation will continue one approved phase at a time. Start with [the architecture](docs/architecture.md), [cost plan](docs/cost-plan.md), and [implementation plan](docs/implementation-plan.md).

## Current status

- Architecture and ownership model: proposed
- Git repository: initial documentation and Phase 1 bootstrap commit published to `main`
- Local CODEOWNERS: prepared for `@Elzabeth-L` (platform/EKS) and `@gokulk18` (EC2/RDS)
- Remote `main` protection: active; one approval, CODEOWNER review, stale-review dismissal, last-pusher separation, administrator enforcement, linear history, conversation resolution, and force-push/deletion blocking enabled.
- Phase 1 backend: applied successfully; `7 added / 0 changed / 0 destroyed`; bootstrap state migrated to S3
- Phase 2 primary network: complete; 35 resources from the initial apply plus six Free Tier-compatible NAT resources from the revised apply
- Phase 3 DR network: complete; `29 added / 0 changed / 0 destroyed` in `ap-southeast-1`, with no NAT or compute
- Combined Phases 4-5 AWS stack: complete; `13 added / 0 changed / 0 destroyed` for Route 53 and six GitHub OIDC roles/policies
- Terraform code: backend, primary network, DR network, and global DNS/OIDC/IAM deployed; Kubernetes code: none
- GoDaddy settings changed: none; GitHub `main` protection plus three two-person apply environments configured
- Next gate: publish and run OIDC smoke tests, then manually delegate `dr.vaultrix.in` at GoDaddy and verify public DNS before Phase 6

## Core intent

- Primary Region: `ap-south-1` (Mumbai)
- DR Region: `ap-southeast-1` (Singapore)
- Strategy: cross-Region backup-and-restore with pilot-light networking
- DNS delegation: `dr.vaultrix.in` from GoDaddy to Route 53
- Independent Terraform states and ownership for shared, EKS, and EC2 work
- Manual disaster declaration and cost-controlled DR activation
