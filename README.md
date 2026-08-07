# Disaster Recovery Project

Documentation-first design for a cost-conscious AWS disaster recovery lab covering an AWS-native EC2/RDS application and an EKS/PostgreSQL application.

No infrastructure is implemented in the current phase. The approved implementation will use Terraform and proceed one phase at a time. Start with [the architecture](docs/architecture.md), [cost plan](docs/cost-plan.md), and [implementation plan](docs/implementation-plan.md).

## Current status

- Architecture and ownership model: proposed
- Local Git repository: initialized on `main`, remote set to `https://github.com/Elzabeth-L/Disaster-Recovery.git`, no commits yet
- Local CODEOWNERS: prepared for `@Elzabeth-L` (platform/EKS) and `@gokulk18` (EC2/RDS)
- Remote branch protection: pending a remote `main` branch and authenticated GitHub administration access
- Phase 1 backend: code validated; plan is `7 add / 0 change / 0 destroy`; awaiting apply approval
- AWS resources created: none
- Terraform/Kubernetes code: none
- GoDaddy or GitHub settings changed: none
- Next gate: owner approval of the documented decisions, followed by the explicit instruction `Approved. Start Phase 1.`

## Core intent

- Primary Region: `ap-south-1` (Mumbai)
- DR Region: `ap-southeast-1` (Singapore)
- Strategy: cross-Region backup-and-restore with pilot-light networking
- DNS delegation: `dr.vaultrix.in` from GoDaddy to Route 53
- Independent Terraform states and ownership for shared, EKS, and EC2 work
- Manual disaster declaration and cost-controlled DR activation
