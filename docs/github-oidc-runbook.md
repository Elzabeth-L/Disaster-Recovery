# GitHub OIDC and Apply Environments

GitHub Actions authenticates to AWS with short-lived OIDC sessions. No AWS access key is stored in GitHub.

## Repository controls

Repository variables hold the six non-secret IAM role ARNs and the primary/DR Region names. Apply jobs use exactly one of these protected environments:

- `shared-apply`
- `eks-apply`
- `ec2-apply`

Each environment accepts deployments only from protected branches. `@Elzabeth-L` is an eligible reviewer; `@gokulk18` remains an additional reviewer where configured. Self-review is allowed so either engineer can complete an approved deployment when the other is unavailable.

## Trust subjects

Plan roles accept only this repository's immutable-ID `pull_request` subject and protected `main` ref. Apply roles accept only their exact environment subject. The repository portion is `Elzabeth-L@262315662/Disaster-Recovery@1326425087`, as observed in CloudTrail and confirmed against the GitHub owner/repository IDs. All roles also require audience `sts.amazonaws.com`; no trust subject contains a wildcard.

The account-level provider `token.actions.githubusercontent.com` already existed and is managed by another project's Terraform state. This project references it read-only and owns only its six roles/policies.

## Authentication verification

The temporary OIDC smoke-test workflow was removed after all six trust paths were verified. Use the read-only `Plan` operation in the owning infrastructure workflow to verify authentication without mutating AWS. Apply operations continue to use state-specific concurrency, reviewed exact plans, typed DR confirmation, and the owning protected environment.

## Permission evolution

Current roles provide scoped Terraform-state access, explicit cross-owner state-write denials, and only the reviewed EKS, EC2/RDS, temporary DR egress, DNS, and application-deployment permissions required by this project.

To disable CI access, disable the workflows/environments first, then remove the role trust or roles through the global/shared state. Do not delete or mutate the shared account OIDC provider because another Terraform state owns it.
