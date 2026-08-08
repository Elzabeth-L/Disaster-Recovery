# Implementation Plan

Status: Phases 0-6 are complete. Shared contract `1.0.0`, public DNS delegation, ownership-scoped OIDC, path-aware CI, and the zero-resource EC2 consumer plan are verified. Phases 7A and 7B may begin; apply-role smoke testing remains a two-person operational exercise.

## Sequencing rules

- Implement one phase at a time. Every phase ends with changed files, validation output, proposed/actual resources, cost impact, and an explicit statement of whether AWS was changed.
- No apply occurs from a PR. Any apply uses an approved, state-specific workflow/environment and OIDC after those controls exist.
- Phase 7A and 7B may proceed in parallel only after Phase 6 freezes shared contract v1.
- Backup and restore are not accepted merely because jobs report success; at least one restore test is required.
- Regional cutover is manual after destination validation. Cleanup is part of every drill.

## Phase 0 - Repository/bootstrap design

- **Objective:** initialize the monorepo and non-deploying engineering guardrails.
- **Resources:** no AWS resources.
- **Files:** `.gitignore`, `.editorconfig`, README refinements, directory READMEs, validation-only Makefile/scripts, proposed CODEOWNERS after usernames, dependency/version policy, initial validation workflows with no apply permission.
- **Dependencies:** approval of this plan; GitHub URL/usernames for ownership settings.
- **Owner:** platform; both review shared CI/CODEOWNERS.
- **Cost:** none.
- **Tests:** secret scan, Markdown/YAML lint, workflow syntax, path-filter tests.
- **Acceptance:** repository is Git-initialized, no generated/secrets tracked, `main` protection instructions applied manually by owner, validation checks pass.
- **Rollback/cleanup:** revert repository-only commits; no cloud cleanup.

## Phase 1 - Terraform backend/bootstrap

- **Objective:** create a protected S3 backend that supports independent state prefixes and native lockfiles.
- **Resources:** one globally named S3 bucket in the approved state Region, versioning, Block Public Access, encryption, TLS-only/bucket/IAM policy; optional access logging only if approved. No DynamoDB lock table.
- **Files:** `terraform/bootstrap/*`, bootstrap README, backend migration/runbook, cost/security tests.
- **Dependencies:** Phase 0, AWS account/identity, backend Region and unique bucket name, budget alerts preferably configured manually first.
- **Owner:** platform.
- **Cost:** low storage/request cost; optional KMS/logging increases it.
- **Tests:** fmt/init/validate/plan, policy scan, local-state backup, apply only after approval, second init with `use_lockfile`, concurrent-lock test, version recovery test.
- **Acceptance:** encrypted/versioned/non-public bucket, least-privilege prefix model documented, bootstrap state safely migrated/backed up, no credentials in config.
- **Rollback/cleanup:** disable consumers, preserve/download state versions, remove empty test objects; bucket deletion is a separately approved destructive action.

## Phase 2 - Shared primary networking

- **Objective:** establish Mumbai shared network contract.
- **Resources:** VPC, two-AZ subnets/routes, IGW, approved egress primitive if separately authorized, S3 gateway endpoint, shared network tags. No EKS/EC2/RDS/ALB.
- **Files:** networking/endpoint modules, `terraform/environments/primary/shared/*`, tests and README.
- **Dependencies:** Phase 1; approved eight-subnet plan; current NAT instance versus managed NAT pricing and reliability test; verified AZ/quota data.
- **Owner:** platform; collaborator reviews outputs.
- **Cost:** most primitives low/no hourly fee; NAT, public IPv4, flow logs, or endpoints are billed and require explicit plan callout.
- **Tests:** Terraform validations/policy tests; route/subnet/AZ assertions; endpoint access test from a short-lived approved test method if needed.
- **Acceptance:** no database IGW route, deterministic subnet outputs, load-balancer tags, S3 endpoint and contract v1 outputs validated; NAT instance passes node/image/controller egress tests or is explicitly replaced with one NAT Gateway.
- **Rollback/cleanup:** destroy only this root after proving no consumers; preserve plan/state evidence and remove temporary test resources.

## Phase 3 - Shared DR networking

- **Objective:** create functionally matching Singapore pilot-light networking without compute.
- **Resources:** DR VPC, subnets/routes/IGW, S3 gateway endpoint; no permanent NAT.
- **Files:** `terraform/environments/dr/shared/*`, reused modules, regional validation.
- **Dependencies:** Phases 1-2 and confirmed Singapore AZ/service/quota support.
- **Owner:** platform.
- **Cost:** low; no compute/hourly egress service by default.
- **Tests:** same network assertions as primary, CIDR non-overlap, destination S3/backup policy review.
- **Acceptance:** recovery subnet capacity and outputs exist, no continuously running DR compute.
- **Rollback/cleanup:** destroy DR shared root only when no recovery copy/policy depends on it; networking can remain as pilot light after approval.

## Combined Phases 4-5 - DNS, GitHub OIDC, and IAM

- **Objective:** prepare delegated project DNS and establish short-lived, ownership-scoped CI authentication in one global/shared delivery.
- **Resources:** one Route 53 public hosted zone for `dr.vaultrix.in` with no application failover record until targets exist; one account OIDC provider if absent; shared/EKS/EC2 least-privilege roles and policies, preferably with plan/apply separation.
- **Files:** global/shared Route 53 and OIDC/IAM modules/root, policy documents, trust-policy tests, delegation and GitHub Environment setup guides, DNS validation script/runbook.
- **Dependencies:** Phases 0-3; approved global state; exact GitHub repository, protected refs, and environments; state-prefix model; access to edit GoDaddy manually later.
- **Owner:** platform; both engineers review trust and EC2 permissions. GoDaddy delegation remains a manual owner action.
- **Cost:** low Route 53 hosted-zone/query cost; IAM/OIDC has no direct hourly cost; workflow usage is subject to the GitHub plan.
- **Tests:** zone/NS outputs; no conflicting root records; allowed GitHub ref assumes only its correct role; wrong repository/branch/environment is denied; each role is denied another ownership/state scope; independent `dig`/`Resolve-DnsName` checks after separately authorized delegation.
- **Acceptance:** hosted zone and four assigned name servers are stable; no static AWS keys or AdministratorAccess; apply roles are environment-gated; CloudTrail identity is attributable; delegation is performed and verified only after explicit authorization.
- **Rollback/cleanup:** remove GoDaddy delegation before deleting the zone; disable GitHub environments/workflows and detach policies before removing unused roles/provider; every deletion requires an exact inventory and explicit approval.

## Phase 6 - Merge shared foundation and handoff

- **Objective:** validate state separation, freeze contract v1, and make collaborator independently productive.
- **Resources:** no new workload resources; optional budget/alert guardrails if authorized.
- **Files:** finalized outputs, CODEOWNERS, path-filtered shared PR workflow, onboarding/runbooks, contract changelog.
- **Dependencies:** Phases 1-3, combined Phases 4-5, and both engineers' review.
- **Owner:** platform; collaborator performs consumer proof.
- **Cost:** no material new runtime cost beyond approved guardrails.
- **Tests:** dummy/read-only EC2 root resolves only its allowed outputs; CI path-filter matrix; cross-state IAM denial; clean clone onboarding test.
- **Acceptance:** shared CI green, contract `1.0.0`, collaborator can plan a no-resource consumer without modifying shared state, branch protection manually confirmed.
- **Rollback/cleanup:** revert docs/CI changes; do not roll back stable output names without coordinated migration.

## Phase 7A - EKS implementation

- **Objective:** deploy the primary EKS platform and a simple notes application with distinct infrastructure, desired state, and data ownership.
- **Resources:** EKS standard-support cluster, managed nodes, EBS CSI add-on, workload identity, AWS Load Balancer Controller, ALB, simple notes application, PostgreSQL StatefulSet/gp3 PVC, application DNS only after health.
- **Files:** EKS modules/root, `kubernetes/base` and primary overlay, EKS app, validation/deploy runbook and EKS workflows.
- **Dependencies:** Phase 6; approved egress model; version compatibility matrix; secrets and container registry decisions.
- **Owner:** platform/EKS owner.
- **Cost:** high: control plane, nodes, EBS, ALB, egress/public IPv4. Tear-down/schedule policy must be decided first.
- **Tests:** Terraform/chart/schema lint, cluster/add-on/node health, topology/storage binding, app/PostgreSQL tests, pod/node deletion tests, ALB health, no public DB.
- **Acceptance:** reproducible deployment, persistent database survives Pod recreation, least-privilege identities, documented cost and cleanup.
- **Rollback/cleanup:** protect/backup data first; remove app/ALB/PVC per runbook, destroy EKS root, then verify ENIs/LBs/EBS/NAT remnants.

## Phase 7B - EC2/RDS implementation

- **Objective:** let collaborator implement the primary AWS-native application without touching shared/EKS ownership.
- **Resources:** EC2 launch template/ASG or justified single instance, ALB/target group, app SGs, private RDS PostgreSQL/subnet group, app DNS, SSM/monitoring prerequisites as approved.
- **Files:** EC2/RDS/ALB modules/root, EC2 app, EC2-only workflows/runbook.
- **Dependencies:** Phase 6; collaborator's application decisions and database secret mechanism.
- **Owner:** collaborator; platform reviews contract/security.
- **Cost:** high: RDS, ALB, EC2, EBS, egress/public IPv4.
- **Tests:** lint/plan/security, target health, DB only reachable from app SG, reboot/instance replacement, migrations/smoke tests.
- **Acceptance:** independent EC2 state and CI, healthy app, no shared/EKS changes, recoverable immutable/mutable boundary documented.
- **Rollback/cleanup:** snapshot/backup data, drain targets, destroy EC2 root, verify ALB/ENI/EBS/RDS snapshots retained or deleted per policy.

## Phase 8 - Backup configuration

- **Objective:** establish tested, non-duplicative cross-Region recovery data.
- **Resources:** versioned/encrypted S3 repositories and selective replication, Velero, CSI snapshots/copies where selected, pgBackRest/WAL, AMI/EBS/RDS backup/copy, narrow AWS Backup vault/plan.
- **Files:** backup modules/config, schedules, restore scripts/runbooks, retention matrix and evidence templates.
- **Dependencies:** Phase 7A/7B workloads, KMS/copy permissions, destination quotas.
- **Owner:** EKS owner for Velero/pgBackRest; collaborator for EC2/RDS/AWS Backup; platform for shared destination policy.
- **Cost:** medium/high storage, requests, cross-Region transfer, KMS; controlled by retention/exclusions.
- **Tests:** forced backup, cross-Region presence, checksum/catalog validation, isolated restore of each authoritative path, expired-backup cleanup.
- **Acceptance:** successful restore evidence meets initial RPO, destination is usable during source unavailability, overlapping RDS schedules removed.
- **Rollback/cleanup:** disable schedules first, preserve minimum evidence, expire/delete recovery points only under approved retention; never casually remove immutable copies.

## Phase 9 - Monitoring and alerting

- **Objective:** detect application/backup failures from both inside and outside workload failure domains.
- **Resources:** lightweight kube-prometheus-stack, PostgreSQL/Velero metrics, EC2/RDS/ALB CloudWatch alarms, SNS notifications, Route 53/ALB health signals.
- **Files:** monitoring values/manifests, alarms, dashboards, alert test/runbook.
- **Dependencies:** Phases 7-8 and notification endpoints.
- **Owner:** each application owner; platform owns shared/external signals.
- **Cost:** medium for EKS resources/log retention/alarms; minimize cardinality and retention.
- **Tests:** synthetic app failure, backup failure, notification delivery, prove external alarm persists when EKS is unavailable.
- **Acceptance:** actionable alerts with owner/runbook/severity; no claim that in-cluster monitoring detects total cluster loss.
- **Rollback/cleanup:** remove test alarms/data and reduce retention; preserve incident evidence.

## Phase 10 - DR infrastructure automation

- **Objective:** create on-demand DR application roots and ordered restore orchestration without automatic disaster declaration.
- **Resources:** temporary DR egress, EKS/nodes/ALBs, EC2/ALB/RDS/EBS as invoked; never always-on by default.
- **Files:** DR roots, manual workflows, preflight/quota/backup checks, restore/cleanup scripts and runbooks.
- **Dependencies:** Phases 3, 5, 7-9; verified backups; approved typed confirmation and GitHub Environment.
- **Owner:** shared orchestration by platform; application restore steps by respective owner.
- **Cost:** high but time-bounded.
- **Tests:** plan-only dry runs, missing-backup/quota abort tests, controlled component restore, idempotent rerun, cleanup rehearsal.
- **Acceptance:** workflow cannot be alarm-triggered; preflight prevents empty/old recovery; on-demand stacks restore without owning shared resources.
- **Rollback/cleanup:** abort before DNS, preserve data evidence, destroy app roots in reverse dependency order, verify billable remnants.

## Phase 11 - DNS failover

- **Objective:** safely cut traffic only after a restored destination is healthy.
- **Resources:** application-owned Route 53 records/health behavior; DR alias exists only while destination exists.
- **Files:** DNS modules in app roots, cutover/switchback workflow, validation and approval checklist.
- **Dependencies:** Phase 10 successful restore and delegated zone.
- **Owner:** each application owner; incident commander/platform approves shared event.
- **Cost:** low DNS/health checks; endpoints already billed.
- **Tests:** diagnostic hostnames, TTL observation, target-health behavior, smoke tests from independent resolver/location.
- **Acceptance:** no dangling alias, single approved writer Region, measured propagation, rollback path tested.
- **Rollback/cleanup:** switch record to last validated target, wait/verify, then remove failed endpoint after evidence.

## Phase 12 - DR drills and RPO/RTO measurement

- **Objective:** execute controlled AZ and regional scenarios and establish empirical recovery performance.
- **Resources:** temporary DR stacks and test data only.
- **Files:** completed scenario runbooks, evidence/results, after-action report, updated objectives.
- **Dependencies:** Phases 8-11 and scheduled team window/budget.
- **Owner:** both engineers with named incident commander/timekeeper.
- **Cost:** high during drill plus backup/transfer; pre-approved ceiling.
- **Tests:** selected EC2/EKS/data/network scenarios, integrity markers, alerts, DNS, cleanup.
- **Acceptance:** recorded actual RPO/RTO per component, passed integrity/smoke checks, issues assigned, no untracked resources.
- **Rollback/cleanup:** stop drill on abort criterion, return DNS/writes safely, destroy DR compute, verify account inventory/cost.

## Phase 13 - Failback

- **Objective:** prove controlled return to Mumbai without split brain or data loss.
- **Resources:** rebuilt primary components and temporary transfer capacity as required.
- **Files:** authoritative-data decision record, failback runbooks/scripts, validation/evidence report.
- **Dependencies:** successful Phase 12 failover and current DR backup.
- **Owner:** both; database/application owner controls writes.
- **Cost:** high while both sides temporarily exist.
- **Tests:** write fence, data checksum/counts, primary smoke tests, DNS switchback, post-switch writes, DR shutdown.
- **Acceptance:** one authoritative writer, primary healthy, evidence backups retained, temporary DR compute removed.
- **Rollback/cleanup:** if validation fails, keep traffic/writes in DR, rebuild primary again; never enable both writers.

## Phase 14 - Cleanup and cost review

- **Objective:** close the project loop and remove unintended recurring cost.
- **Resources:** delete/stop only approved temporary resources; retain defined pilot-light network and backups.
- **Files:** final inventory, cost report, retention decisions, backlog/production-upgrade recommendations.
- **Dependencies:** all executed phases and backup evidence.
- **Owner:** platform with both application owners confirming their states.
- **Cost:** should reduce recurring spend; deletions and retrieval can have final charges.
- **Tests:** state-to-account inventory, Cost Explorer review, expiration tag scan, DNS/backup checks.
- **Acceptance:** no forgotten EKS/RDS/EC2/ALB/NAT/public IPv4/unattached EBS; measured cost documented; retained resources have owner/reason/expiry.
- **Rollback/cleanup:** recovery from deletion uses state bucket versions/backups where possible; destructive cleanup always has an exact reviewed target list.

## Genuine blockers before implementation

The documentation can be approved now. The following values block their respective implementation phases, not this review:

1. AWS account ID/account model, available IAM Identity Center setup, and billing/credits context.
2. Monthly budget and alert email/SNS destination.
3. Whether `Elzabeth-L/Disaster-Recovery` is public or private; GitHub identities are `@Elzabeth-L` and `@gokulk18`.
4. Owner and CostCenter tag values.
5. Final NAT instance size after current Mumbai price/throughput validation; one managed NAT Gateway is the fallback.
6. Application container/source requirements and collaborator's EC2/RDS sizing/availability choices.

Resolved: retain eight subnets, add bootstrap/global state, target continuous primary EKS during active project windows with cost-triggered teardown outside them, and use Secrets Manager plus AWS-managed encryption keys initially.
8. Secret management choice and whether customer-managed KMS keys are required.

## Exact proposed implementation sequence

Approve decisions -> Phase 0 repository guardrails -> Phase 1 backend -> Phase 2 primary shared network -> Phase 3 DR shared network -> combined Phases 4-5 DNS preparation/delegation and GitHub OIDC/IAM -> Phase 6 contract freeze/handoff -> Phases 7A and 7B in parallel -> Phase 8 backups and restore proof -> Phase 9 monitoring -> Phase 10 on-demand DR automation -> Phase 11 DNS cutover -> Phase 12 drills -> Phase 13 failback -> Phase 14 cleanup/cost review.
