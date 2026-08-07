# Terraform Conventions

## Toolchain candidates verified 2026-08-07

These are documentation-time pins, not implementation files. Reverify compatibility and checksums immediately before Phase 0/1.

| Component | Candidate pin | Rationale/source |
|---|---:|---|
| Terraform CLI | `1.15.8` | Current stable patch in official HashiCorp releases; use Terraform, not OpenTofu |
| AWS provider | `6.54.0` | Newest 6.x release resolved by the live Registry for this workspace on 2026-08-07; pin exact lockfile |
| Helm provider | `3.2.0` | Current official Registry version |
| EKS Kubernetes | `1.35` candidate (while `1.36` is current) | AWS lists 1.36 as newest standard support; select one-minor-back 1.35 initially to give add-ons/controllers a compatibility margin, then prove the matrix before pinning |
| kubectl | `1.35.x` | Match cluster minor; Kubernetes permits limited skew but matching reduces surprises |
| Velero | `1.18.2` | Current official stable release |
| pgBackRest | `2.59.0` | Current stable upstream release |
| AWS Load Balancer Controller | `3.5.0` candidate | Current upstream stable; contains Gateway API migration requirements; validate Ingress-only configuration |
| EBS CSI driver | EKS add-on compatible build based on `1.63.1` upstream | Query `describe-addon-versions` in both Regions for EKS 1.35 before pinning |
| kube-prometheus-stack | `87.18.1` candidate | Current chart; includes Prometheus/Grafana/Alertmanager; security scan and resource tuning required |

References: [Terraform releases](https://github.com/hashicorp/terraform/releases), [AWS provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs), [Helm provider](https://registry.terraform.io/providers/hashicorp/helm/latest), [EKS document history](https://docs.aws.amazon.com/eks/latest/userguide/doc-history.html), [Velero releases](https://github.com/velero-io/velero/releases/latest), [pgBackRest releases](https://pgbackrest.org/release.html), [AWS Load Balancer Controller releases](https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/latest), [EBS CSI releases](https://github.com/kubernetes-sigs/aws-ebs-csi-driver/releases/latest), and [kube-prometheus-stack](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack).

Do not use `latest`. Chart/app/provider compatibility takes precedence over freshness; a candidate may be lowered after a documented test without changing architecture. EKS 1.35 remains in standard support until 2027-03-27; if all required add-ons explicitly support 1.36 at implementation time, prefer 1.36 after review.

## Root and module structure

- Reusable modules contain resources; roots compose modules, providers, backends, and environment values.
- One root maps to one state and one ownership boundary. No Terraform workspaces for primary/DR separation.
- Provider aliases are explicit for cross-Region operations. Modules receive providers from roots and do not silently configure them.
- Modules are small enough to test but not one-resource wrappers. Prefer clear repetition to meta-programming that hides ownership.

Standard root files later: `versions.tf`, `providers.tf`, `backend.tf`, `variables.tf`, `locals.tf`, `main.tf`, `outputs.tf`, `terraform.tfvars.example`, and `README.md`. Backend blocks use partial configuration and never embed credentials.

## State and locking

Use an S3 backend with versioning, encryption, Block Public Access, and `use_lockfile = true`. HashiCorp documents S3 lockfiles and deprecates DynamoDB locking. Do not create a new DynamoDB table. Bootstrap begins with local state, creates the protected bucket, then migrates after explicit review. The bootstrap state itself is backed up and tightly controlled.

## Code rules

- `terraform fmt` canonical formatting; UTF-8 and LF; descriptive variables with types, descriptions, validations, and safe defaults.
- No hard-coded account IDs, credentials, secrets, or AZ letter assumptions.
- Central locals for naming/tags. Prefer `for_each` with stable keys over numeric `count` where identity matters.
- Every output has description and appropriate sensitivity. Never output credentials/database passwords.
- Exact dependency versions are recorded in `.terraform.lock.hcl`; automated upgrades use reviewed PRs.
- Lifecycle protection is reserved for state/backup-critical resources and documented. It is not a substitute for permissions/approval.
- Cross-stack references use the contract; never duplicate/import another owner's resource.

## Validation gates

PR: `fmt -check`, `init -backend=false` where possible, `validate`, TFLint, security/policy scan, documentation lint, and speculative plan with read-only credentials when safe. Apply: approved plan artifact or a freshly reviewed plan, protected environment, OIDC, concurrency lock, and post-apply tests. A DR apply is manual only.
