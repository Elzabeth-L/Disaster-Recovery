# Security

## Identity and access

- Humans use IAM Identity Center/SSO where available, otherwise individual IAM identities with MFA and role assumption. Credentials are never shared.
- GitHub Actions uses OIDC with separate shared, EKS, and EC2 roles. Trust policies restrict repository, branch/environment, and audience claims.
- Plan roles are read-oriented; apply roles are protected by GitHub Environments and scoped to owned state/resource tags. No permanent `AdministratorAccess`.
- Application stacks cannot write another stack's state prefix or shared resources.
- Kubernetes uses workload identity (EKS Pod Identity or IRSA, selected during EKS design) for Velero, pgBackRest, CSI, and controller access; no node-wide broad credentials.

## Secrets and state

Secrets, access keys, kubeconfig, state, plans, `.terraform`, environment files, and generated credentials are excluded from Git. Store application/database runtime credentials in AWS Secrets Manager and retrieve them through a workload identity integration selected during EKS/EC2 implementation; do not place secret values in Terraform-managed outputs or committed manifests. Use AWS-managed encryption keys initially and introduce customer-managed KMS keys only for a documented copy, separation, or compliance requirement.

The state bucket uses Block Public Access, versioning, server-side encryption, TLS-only access, access logging if cost-approved, least-privilege object-prefix policies, and S3 lockfiles. State readers are privileged because state can contain sensitive values. Break-glass state recovery is documented and audited.

## Network and data controls

- RDS is not public and accepts PostgreSQL only from its application security group.
- Database subnets have no direct Internet route.
- ALBs expose only required HTTP/HTTPS listeners; production upgrade requires ACM TLS before public use.
- SSH is disabled by default. Prefer SSM; if its paid endpoint/egress dependencies are not present, use a time-limited, source-restricted lab method approved for the drill.
- EC2 requires IMDSv2. EBS, RDS, S3, snapshots, backup vaults, and AMIs are encrypted where supported.
- S3 buckets enable Block Public Access, versioning, lifecycle policy, and scoped bucket/endpoint policies.
- Security groups reference security groups rather than broad CIDRs where service semantics permit.

## Supply chain and CI

Pin Terraform, providers, Helm charts, containers, and GitHub Actions to reviewed versions; actions should ultimately use commit SHAs. PRs run format, validate, TFLint, Checkov/tfsec-equivalent policy checks, secret scanning, YAML/schema checks, and plan review. A reported scanner vulnerability is triaged rather than automatically ignored.

## Backup security

Destination vault/bucket policies must prevent application roles from deleting recovery evidence. Cross-Region KMS permissions are tested before relying on copies. Production upgrade uses a separate backup account and Vault Lock after retention has been tested; compliance mode is intentionally deferred because it can make deletion irreversible.

## Threats to test

- OIDC claim too broad; role assumed from an untrusted branch/fork.
- One owner able to modify another state/resource.
- Public RDS/node/SSH exposure.
- Secret appearing in a plan, state output, workflow log, or Kubernetes manifest.
- Backup exists but is unreadable due to KMS/bucket/identity policy.
- DNS cutover without validated destination or write fencing.
