# Gokul Handoff Timing and Package

## When Gokul may start

Gokul should not start EC2/RDS Terraform yet. He may install tools, obtain repository access, read the architecture, and decide his application design now. Infrastructure work begins after Phase 6, when all of the following are complete:

- Backend and state locking work.
- Primary and DR shared networking are applied and validated.
- Route 53 hosted zone/delegation is prepared.
- GitHub OIDC roles and path-filtered validation are working.
- Shared output contract is frozen at version `1.0.0`.
- A read-only consumer proof shows the EC2 root can read shared outputs without managing shared resources.

## What to give Gokul

1. GitHub collaborator invitation with Write permission and protected-branch PR instructions.
2. [Collaborator onboarding](collaborator-onboarding.md), [shared infrastructure contract](shared-infrastructure-contract.md), networking, naming, security, cost, and EC2 runbook links.
3. His own IAM Identity Center user/group and EC2 plan/apply roles; never the owner's AWS login or credentials.
4. State contract values and locations: `primary/shared`, `dr/shared`, `global/shared`; write access only to `primary/ec2` and `dr/ec2`.
5. Stable outputs: VPC ID, public/EC2/database subnet IDs, Regions, hosted-zone ID/name, common tags, and contract version.
6. Ownership statement: he owns EC2 ALB/target group, launch template/ASG or approved instance design, EC2 and RDS security groups, RDS, EC2 backup/monitoring, and EC2 DNS records.
7. Prohibited-resource list: VPCs, shared subnets/routes, hosted zone, S3 gateway endpoint, backend bucket, GitHub OIDC provider, shared IAM/networking, and EKS resources.
8. CI check names, plan-review procedure, manual apply policy, DR enable/confirmation variables, budget ceiling, and cleanup checklist.

## Before his first feature branch

- Confirm `@gokulk18` accepts the repository invitation; CODEOWNERS already assigns EC2 paths to him and shared paths to both engineers.
- Pair on a clean clone and AWS SSO login.
- Run a no-resource remote-state consumer plan.
- Agree on EC2 application packaging, instance/ASG approach, RDS size/engine version, secrets integration, backup authority, and primary availability/cost mode.
- Create `feature/ec2-rds-platform` from the latest protected `main` and keep PRs small.
