# Collaboration and GitHub Model

## Repository workflow

Initialize one monorepo after documentation approval. Protect `main`; no direct pushes. Work in short-lived branches, rebase/update frequently, and merge reviewed PRs only after required checks.

Reduced branch groupings:

- `feature/shared-foundation` for small reviewed slices of backend/network/DNS/OIDC (do not keep it open for weeks)
- `feature/eks-platform` for EKS infrastructure/storage/add-ons
- `feature/eks-recovery-observability` for backup, monitoring, and DR
- `feature/ec2-rds-platform` for collaborator's compute/database foundation
- `feature/ec2-recovery-observability` for AWS Backup, monitoring, and DR
- `docs/<topic>` and `fix/<scope>` as needed

Branch names group the original list without making long-lived parallel branches. Prefer multiple PRs from the same theme.

## Protection for `main`

- Require pull requests and required status checks.
- Require one approval where the two-person plan permits; dismiss stale approvals after material changes.
- Require conversation resolution and block force pushes/deletion.
- Require branch up to date if checks are fast/reliable; otherwise use a merge queue later.
- Restrict apply through GitHub Environments, not merely branch protection.
- Administrators should follow the rule except documented break-glass incidents.

## CODEOWNERS proposal

The platform/EKS owner is `@Elzabeth-L`; the EC2/RDS owner is `@gokulk18`. Shared documentation, networking, contract, and GitHub configuration receive joint review.

```text
*                                      @Elzabeth-L
/docs/                                 @Elzabeth-L @gokulk18
/terraform/bootstrap/                  @Elzabeth-L
/terraform/environments/global/        @Elzabeth-L
/terraform/environments/*/shared/      @Elzabeth-L @gokulk18
/terraform/environments/*/eks/         @Elzabeth-L
/kubernetes/                            @Elzabeth-L
/applications/eks-app/                 @Elzabeth-L
/terraform/environments/*/ec2/         @gokulk18
/applications/ec2-app/                 @gokulk18
/.github/                               @Elzabeth-L @gokulk18
```

## Target branch rules for `main`

- Initial bootstrap rule: require a pull request, conversation resolution, linear history, and block force pushes/deletions. Do not require an approval or CODEOWNER review until `@gokulk18` accepts the collaborator invitation, avoiding a two-person repository lockout.
- After `@gokulk18` accepts: require one approval, dismiss stale approvals, and require CODEOWNER review.
- Require linear history. Require signed commits only after both engineers confirm their tooling.
- Do not require status-check names until validation workflows have run at least once; otherwise an empty repository can become unmergeable. Add the verified check names in Phase 0.
- Apply rules to administrators after the initial bootstrap commit and keep recovery access documented.

## CI/CD boundaries

- Shared paths trigger shared validation/plan only.
- EKS Terraform, Kubernetes, and EKS app paths trigger EKS checks only.
- EC2/RDS/Backup and EC2 app paths trigger EC2 checks only.
- Documentation changes run docs/secret checks and no cloud apply.
- PRs plan; merges do not automatically create DR resources. Applies use manual dispatch, environment approval, OIDC, state-specific concurrency, and a typed confirmation for DR/cutover.

Separate OIDC roles should distinguish plan/apply if policy size remains maintainable. Trust is limited to the eventual repository and protected refs/environments. GitHub-hosted PRs from forks never receive an apply role.

## Review contract

Shared contract or workflow changes require both engineers. Each application owner approves changes in their state. Plans are checked for ownership violations, replacements/deletions, public access, untagged resources, region/state key, cost-bearing resources, and cleanup implications.
