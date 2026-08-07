# Local Development

## Supported workflow

Linux, macOS, WSL2, or PowerShell are acceptable if repository commands have equivalents. Pin versions through the repository rather than relying on `latest`. Candidate documentation-time versions are in [terraform-conventions.md](terraform-conventions.md).

## Authentication

Use an individual AWS SSO profile with MFA and role assumption. Set `AWS_PROFILE` and `AWS_REGION` for the intended read/plan task; verify with `aws sts get-caller-identity`. Never place credentials, account secrets, kubeconfig, plan files, or generated environment files in Git. GitHub CLI authentication is separate from AWS authentication.

## Expected checks after implementation begins

```bash
terraform version
aws --version
kubectl version --client
helm version
git status
terraform fmt -check -recursive
terraform -chdir=<root> init -backend=false
terraform -chdir=<root> validate
tflint --chdir=<root>
```

Security/YAML/schema tools will be pinned in Phase 0. A local plan uses the exact root and approved backend config; never run a plan from the repository root and never use `-auto-approve`. Save plans only in ignored temporary locations and remove them after review.

## Safe environment selection

Directory and backend key must agree: `primary/ec2` uses `primary/ec2/terraform.tfstate`, and so on. Before any plan, display AWS account, role, Region, root path, and state key. DR roots require an explicit enable flag and manual approval in CI. Local applies are disabled by convention after CI roles exist; emergency exceptions are recorded.

## Kubernetes access

Generate kubeconfig only for the intended cluster/profile/Region; it remains in the user's normal kubeconfig location, never the repo. Match `kubectl` to the cluster minor. Apply version-controlled desired state through the documented owner workflow; do not hand-edit live objects as a substitute for Git.

## Troubleshooting guardrails

Do not delete state locks until the owning operation is confirmed dead. Do not use `terraform state rm`, import, forced unlock, targeted apply, or manual console changes without a reviewed recovery note. If provider downloads fail, fix network/authentication rather than committing `.terraform` or binaries.
