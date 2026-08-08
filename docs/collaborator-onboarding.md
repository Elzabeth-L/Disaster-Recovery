# Collaborator Onboarding

This guide is executable for the Phase 6 consumer proof. Workload creation begins only after that proof is merged.

## Repository access

The owner invites collaborator through GitHub repository **Settings -> Collaborators/Manage access -> Add people** using collaborator's own GitHub account. Never share GitHub credentials. `Write` is the usual minimum for branches/PRs in a private two-person lab; do not grant Admin unless he must manage settings. Branch protection means Write access still cannot push directly to `main`.

## Prerequisites

Install versions pinned by the repository: Git, Terraform `1.15.8`, AWS CLI v2, `kubectl` matching EKS minor, Helm 3, Docker only for application builds, and optional GitHub CLI, `jq`, and GNU Make (or documented PowerShell equivalents). Run the checks in [local-development.md](local-development.md).

## AWS authentication

Preferred: provision the collaborator as an individual IAM Identity Center user/group with MFA and permission sets that assume EC2 plan/apply roles. They run `aws configure sso` and `aws sso login --profile <approved-profile>`. The owner's current local AWS login is not shared. If Identity Center is unavailable, create an individual IAM identity with MFA and tightly scoped role assumption; never copy the owner's keys. Local credentials remain outside the repository. CI uses GitHub OIDC, not local/static keys.

## Git workflow

```bash
git clone <REPOSITORY_URL>
cd <REPOSITORY_DIRECTORY>
git switch main
git pull --ff-only
git switch -c feature/ec2-rds-platform
# edit only owned paths, then validate
git status
git add <intentional-files>
git commit -m "feat(ec2): add reviewed unit of work"
git push -u origin feature/ec2-rds-platform
gh pr create --fill                 # optional; otherwise use GitHub UI
```

To update before merge:

```bash
git fetch origin
git rebase origin/main
# resolve each conflict, test, then:
git add <resolved-files>
git rebase --continue
git push --force-with-lease
```

Use `--force-with-lease` only on his own feature branch, never `main`. Ask the platform owner to pair on conflicts in shared contract/workflow files.

## Ownership

collaborator owns EC2 application code and, in `primary/ec2` and `dr/ec2` states only: application ALB/listeners/target groups, launch template, ASG/instances, application/RDS security groups, RDS subnet group/parameters/instance, EC2/RDS backup selections, CloudWatch/SNS app monitoring, AMI/snapshot recovery, and EC2 DNS records.

He must not create or manage VPCs, shared subnets/routes/IGWs, S3 gateway endpoints, the Route 53 hosted zone, Terraform backend, GitHub OIDC provider/shared roles, EKS resources, or shared networking/security groups. Infrastructure choices for his application remain his decisions provided they comply with the shared contract, security/cost guardrails, and review.

## Terraform contract

The EC2 roots read `primary/shared` or `dr/shared` outputs and `global/shared`; they never invoke networking modules. Required inputs include `vpc_id`, `public_subnet_ids`, `ec2_private_subnet_ids`, `database_subnet_ids`, region, tags, and hosted-zone ID. See [shared-infrastructure-contract.md](shared-infrastructure-contract.md) for the illustrative `terraform_remote_state` pattern and exact types.

His security groups are owned wholly by his root. The ALB uses public subnets; compute uses EC2 private subnets; RDS subnet group uses database subnets in both AZs and is never public.

## DNS and state

The hosted zone is shared. collaborator owns only `ec2.dr.vaultrix.in` plus approved `ec2-primary`/`ec2-dr` diagnostics. DNS cutover occurs only after restored targets pass validation and a human approves it. His resource states are exactly `primary/ec2/terraform.tfstate` and `dr/ec2/terraform.tfstate`; he receives read-only access to required shared/global state and write access only to his state prefixes.

## CI and apply

Changes under EC2 Terraform/application paths trigger format, init/validate, lint, security, tests, and an EC2-only plan. Review replacements/deletions, public access, region, tags, and cost. Apply is separate from PR checks and uses a protected GitHub Environment/OIDC role. DR apply is manual and must never be triggered by a health alarm alone.

## Clean-clone Phase 6 proof

From a new directory, with no repository-local credentials or generated Terraform files:

```bash
git clone https://github.com/Elzabeth-L/Disaster-Recovery.git
cd Disaster-Recovery/terraform/environments/primary/ec2
terraform version
terraform fmt -check -recursive
terraform init -backend=false -input=false
terraform validate
```

Open the EC2 consumer PR and let `Terraform PR validation` perform the live plan with GitHub OIDC. The expected plan is `0 to add, 0 to change, 0 to destroy`. Neither local AWS root credentials nor shared static credentials are part of collaborator onboarding.

## Cost safety

Keep DR variables disabled by default. Inspect every plan for EKS/EC2/RDS/ALB/NAT/public IPv4/EBS and cross-Region copy charges. Do not leave drill resources running; execute and evidence the cleanup checklist. Do not add AWS DRS, Multi-AZ RDS, extra ALBs, interface endpoints, or duplicate backup schedules without design/cost approval.
