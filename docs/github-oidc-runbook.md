# GitHub OIDC and Apply Environments

GitHub Actions authenticates to AWS with short-lived OIDC sessions. No AWS access key is stored in GitHub.

## Repository controls

Repository variables hold the six non-secret IAM role ARNs and the primary/DR Region names. Apply jobs use exactly one of these protected environments:

- `shared-apply`
- `eks-apply`
- `ec2-apply`

Each environment accepts deployments only from protected branches. `@Elzabeth-L` and `@gokulk18` are reviewers, and self-review is prohibited. The engineer who starts an apply therefore cannot approve it alone.

## Trust subjects

Plan roles accept only this repository's `pull_request` subject and protected `main` ref. Apply roles accept only their exact environment subject. All roles also require audience `sts.amazonaws.com`; no trust subject contains a wildcard.

The account-level provider `token.actions.githubusercontent.com` already existed and is managed by another project's Terraform state. This project references it read-only and owns only its six roles/policies.

## Smoke test

Run **AWS OIDC smoke test** manually with a scope and access type. Plan tests run immediately from `main`. Apply tests pause for the other engineer's environment approval. The workflow requests only `contents: read` and `id-token: write`, obtains temporary AWS credentials, and checks that STS returned the expected role.

The smoke workflow proves authentication only; it does not run Terraform or mutate AWS. Normal infrastructure workflows are added in Phase 6 with path filters, state-specific concurrency, reviewed plans, typed DR confirmation, and the owning apply environment.

## Permission evolution

Current roles provide scoped Terraform-state access, read-oriented service discovery, explicit cross-owner state-write denials, and owner-specific DNS changes for apply roles. They intentionally do not have broad workload mutation permissions. Phase 7A adds only the reviewed EKS permissions; Phase 7B adds only the reviewed EC2/RDS permissions.

To disable CI access, disable the workflows/environments first, then remove the role trust or roles through the global/shared state. Do not delete or mutate the shared account OIDC provider because another Terraform state owns it.
