# Disaster Recovery Project

Documentation-first design for a cost-conscious AWS disaster recovery lab covering an AWS-native EC2/RDS application and an EKS/PostgreSQL application.

Phases 1-6 are complete: the protected backend, shared networks, DNS/OIDC foundation, and versioned consumer contract are deployed and validated. Implementation continues one approved phase at a time. Start with [the architecture](docs/architecture.md), [cost plan](docs/cost-plan.md), and [implementation plan](docs/implementation-plan.md).

## Current status

- Architecture and ownership model: accepted through shared contract `1.0.0`
- Git repository: Phases 1-6 published to `main`
- CODEOWNERS: active for `@Elzabeth-L` (platform/EKS) and `@gokulk18` (EC2/RDS)
- Remote `main` protection: active; one approval, CODEOWNER review, stale-review dismissal, last-pusher separation, linear history, conversation resolution, and force-push/deletion blocking enabled. Repository administrators may explicitly bypass these review gates.
- Phase 1 backend: applied successfully; `7 added / 0 changed / 0 destroyed`; bootstrap state migrated to S3
- Phase 2 primary network: complete; 35 resources from the initial apply plus six Free Tier-compatible NAT resources from the revised apply
- Phase 3 DR network: complete; `29 added / 0 changed / 0 destroyed` in `ap-southeast-1`, with no NAT or compute
- Combined Phases 4-5 AWS stack: complete; `13 added / 0 changed / 0 destroyed` for Route 53 and six GitHub OIDC roles/policies
- Terraform code: backend, primary network, DR network, and global DNS/OIDC/IAM deployed; Kubernetes code: none
- GoDaddy delegation: complete and independently resolved through Google and Cloudflare DNS
- GitHub OIDC plan-role smoke tests: passed for shared, EKS, and EC2; protected apply-role smoke tests remain a two-person approval exercise
- Phase 6 contract/handoff: complete; all four Terraform roots validate and the OIDC-backed EC2 consumer plan returned zero changes
- Current gate: Phase 7A notes application/EKS implementation is prepared for CI and a reviewed,
  explicitly approved cost-bearing plan; no EKS resources have been applied. Phase 7B may continue
  independently on Gokul's retained feature branches.

## Core intent

- Primary Region: `ap-south-1` (Mumbai)
- DR Region: `ap-southeast-1` (Singapore)
- Strategy: cross-Region backup-and-restore with pilot-light networking
- DNS delegation: `dr.vaultrix.in` from GoDaddy to Route 53
- Independent Terraform states and ownership for shared, EKS, and EC2 work
- Manual disaster declaration and cost-controlled DR activation
