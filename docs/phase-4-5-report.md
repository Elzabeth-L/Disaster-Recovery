# Combined Phases 4-5 DNS and GitHub OIDC/IAM Report

Status: AWS and GitHub control-plane resources applied on 2026-08-07. All plan-role OIDC smoke tests pass; manual GoDaddy delegation and two-person apply-role smoke tests remain.

## Discovery and ownership

The AWS account already contained `token.actions.githubusercontent.com` with audience `sts.amazonaws.com`. Another project's Terraform state owns and tags that account-level provider, so this project references it as a data source and creates no duplicate provider. No Route 53 hosted zones existed before this phase.

The repository is public, its default branch is protected `main`, and no GitHub Environments existed before this phase.

## Applied AWS resources

The reviewed plan contained `13 to add, 0 to change, 0 to destroy` and applied exactly:

- public hosted zone `dr.vaultrix.in`, ID `Z04143692YQRB56PPC4Q3`;
- shared plan and apply IAM roles plus one inline policy each;
- EKS plan and apply IAM roles plus one inline policy each; and
- EC2 plan and apply IAM roles plus one inline policy each.

No OIDC provider, AWS-managed policy attachment, application record, health check, compute resource, or static credential was created. A post-apply Terraform plan reports no changes.

## Route 53 delegation values

AWS assigned these authoritative name servers:

- `ns-261.awsdns-32.com`
- `ns-1049.awsdns-03.org`
- `ns-714.awsdns-25.net`
- `ns-1979.awsdns-55.co.uk`

The hosted zone is public, has `prevent_destroy`, and currently contains only its required SOA/NS records. GoDaddy has not been changed. Delegation must add an NS record for host/subdomain `dr` at the existing `vaultrix.in` DNS provider; it must not replace the root-domain name servers.

## OIDC and state boundaries

- Plan trust: exact `pull_request` and `ref:refs/heads/main` subjects for immutable identity `Elzabeth-L@262315662/Disaster-Recovery@1326425087`.
- Apply trust: exact `shared-apply`, `eks-apply`, or `ec2-apply` environment subject.
- Audience: exactly `sts.amazonaws.com`.
- Wildcard trust subjects: zero.
- Plan roles: state read plus owner-state lockfiles; state writes are denied by omission.
- Apply roles: write only owner state; explicit denies protect every other owner prefix.
- Application DNS: EKS and EC2 apply roles can change only their approved names and A/AAAA/CNAME/TXT record types.
- Broad workload mutation: intentionally absent until the owning Phase 7 resource plan exists.

IAM simulation proved:

- shared plan state write: `implicitDeny`; its lockfile write: `allowed`;
- EKS apply write to EKS state: `allowed`; EC2/shared state writes: `explicitDeny`;
- EC2 apply write to EC2 state: `allowed`; EKS state write: `explicitDeny`; and
- EKS DNS change for `eks.dr.vaultrix.in`: `allowed`; change to `ec2.dr.vaultrix.in`: `implicitDeny`.

## GitHub controls

The repository now has `shared-apply`, `eks-apply`, and `ec2-apply` environments. Each is restricted to protected branches, names both `@Elzabeth-L` and `@gokulk18` as reviewers, and prohibits self-review. Eight non-secret repository variables hold the six role ARNs and two Region names.

The smoke workflow is pinned to immutable commit `e6de054238d6b7531b4efff3b6587d9aade6a06c` of `aws-actions/configure-aws-credentials` v6.2.3. It only requests `contents: read` and `id-token: write`; it does not run Terraform or mutate AWS.

The first shared plan smoke run exposed GitHub's immutable-ID default subject format: CloudTrail showed `repo:Elzabeth-L@262315662/Disaster-Recovery@1326425087:ref:refs/heads/main`. The initial name-only trust was denied as designed. All six role trusts were then corrected to the exact observed identity before further testing.

Post-correction GitHub OIDC results:

- shared plan role: success, run `31190970949`;
- EKS plan role: success, run `31191051630`; and
- EC2 plan role: success, run `31191092195`.

The trust correction updated only the six IAM assume-role policies: `0 added, 6 changed, 0 destroyed`. A subsequent Terraform plan reports no changes. Apply-role tests require the engineer who did not initiate the run to approve the corresponding protected environment, so they are intentionally deferred until Gokul is available.

## Cost and rollback

IAM roles, policies, and OIDC federation have no hourly charge. The public hosted zone is the only material new recurring item, approximately USD $0.50 per month for the first 25 hosted zones plus queries under the standard Route 53 pricing model.

Rollback requires removing GoDaddy delegation first if it has been added, disabling workflows/environments, and then destroying only this global/shared state after a fresh review. The hosted-zone `prevent_destroy` guard must be deliberately removed for deletion. Never delete or modify the externally owned account OIDC provider.
