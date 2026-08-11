# Workflow guide

This repository separates continuous integration, primary deployment, DR infrastructure, and the
DR demonstration. The DR design is a deliberately simple, manually initiated lab. It is not
active-active, and it does not continuously replicate application databases.

## Workflow map

| Workflow | Responsibility |
|---|---|
| `CI - Terraform` | Select and validate only Terraform roots affected by a pull request. |
| `CI - EKS application` | Test and build the notes application image for GHCR. |
| `Primary 1 - EKS infrastructure` | Plan or apply the primary Mumbai EKS platform. |
| `Primary 2 - EKS application` | Deploy the notes application to primary EKS. |
| `Primary 3 - EC2 infrastructure` | Plan or apply the primary EC2/RDS platform. |
| `Primary 4 - EC2 application` | Build and publish the EC2 application image to GHCR. |
| `DR 1 - Infrastructure` | Plan, apply, or destroy temporary Singapore infrastructure. |
| `DR 2 - Drill` | Seed DR data, demonstrate failover/failback, and remove the DR EKS workload. |

## Current DR sequence

```text
DR 1: apply selected DR infrastructure
  -> automatically ensure shared egress for EKS or EC2
DR 2: deploy or refresh DR applications
  -> copy the current primary API data into isolated DR databases
DR 2: fail over to DR
  -> EKS controlled DNS cutover + EC2 health-check failover
DR 2: fail back to primary
  -> EKS controlled DNS restore + EC2 health-check failback
DR 2: remove DR applications
  -> remove Kubernetes workload, EBS volume, EKS-created ALB, controller, and diagnostic DNS
DR 1: destroy EKS, EC2, then shared egress
```

## DR 1 - Infrastructure

DR 1 operates Terraform roots in Singapore (`ap-southeast-1`). Select one component:

- `shared-egress`: temporary NAT instance, EIP, route, and related recovery-egress resources;
- `eks`: EKS control plane, managed nodes, add-ons, IAM, ECR, Secrets Manager, and supporting
  resources;
- `ec2`: EC2 application instance, RDS, ALB, Route 53 failover record, backup, monitoring, and
  supporting resources.

### Operations

| Operation | Effect |
|---|---|
| `Plan deploy` | Read-only plan with the selected component enabled. |
| `Apply deploy` | Create a fresh plan and apply that exact artifact after environment approval. |
| `Plan destroy` | Read-only plan showing what disabling/destroying the selected component removes. |
| `Apply destroy` | Apply the exact destruction plan after environment approval. |

`Plan` never changes AWS. Every `Apply` first creates a fresh plan and passes its exact saved plan
artifact to the apply job.

### Automatic shared-egress prerequisite

Choosing `eks` or `ec2` with a deploy operation now checks `dr/shared` first:

1. Plan shared egress with `recovery_egress_enabled=true`.
2. If the plan has changes and the operation is `Apply deploy`, apply it through `shared-apply`.
3. Plan and, when requested, apply the selected EKS or EC2 component.

If shared egress is already present, its detailed-exit-code plan reports no changes, its apply job is
skipped, and the selected workload continues. The explicit `shared-egress` component remains
available for direct inspection and final destruction.

Shared egress is not destroyed automatically with EKS or EC2 because the other workload may still
need it. Destroy in dependency order:

1. `eks` with `Apply destroy`;
2. `ec2` with `Apply destroy`;
3. `shared-egress` with `Apply destroy`.

Before destroying EKS infrastructure, run DR 2 `Remove DR applications` so Kubernetes can delete
its ALB and persistent volume cleanly.

## DR 2 - Drill

DR 2 assumes the required DR 1 infrastructure already exists. It coordinates application data,
Kubernetes resources, instance power state, health validation, and DNS.

### Deploy or refresh DR applications

For EKS, this operation:

1. Calls the primary notes API and saves its current JSON response as a drill-time logical snapshot.
2. Reads the immutable image digest from the primary EKS deployment.
3. Connects to the existing Singapore EKS cluster.
4. Installs the AWS Load Balancer Controller.
5. Deploys the notes application and single-replica PostgreSQL StatefulSet with an EBS volume.
6. Waits for the DR ALB and validates it.
7. Deletes existing DR notes and inserts the captured primary notes.
8. Publishes `eks-dr.dr.vaultrix.in` as the direct DR diagnostic endpoint.

The AWS Load Balancer Controller watches Kubernetes resources such as `Ingress`. For this project,
it translates the notes `Ingress` into AWS resources: an internet-facing Application Load Balancer,
listener, target group, security-group rules, and registered Kubernetes targets. Without the
controller, applying the Ingress manifest would not provision or continually reconcile that ALB.

For EC2, DR 1 already deployed the container, instance, RDS, and ALB. DR 2 waits until the DR
application reports a connected database, deletes existing DR tasks, copies the captured primary
tasks, and validates `ec2-dr.dr.vaultrix.in`.

This operation defines the demonstration recovery point. Run it while primary is healthy and again
after creating any new `Before DR drill` marker that must be present in Singapore.

### Data protection and replication limits

There is no continuous replication between the EKS PostgreSQL databases. The public endpoints point
to different databases:

- `eks.dr.vaultrix.in` normally uses primary Mumbai PostgreSQL;
- `eks-dr.dr.vaultrix.in` always uses the isolated Singapore PostgreSQL while the DR app exists.

A note written directly to the DR endpoint is therefore not expected to appear at the primary
endpoint. `Deploy or refresh DR applications` copies primary to DR once by reading `/api/notes`; it
is not streaming replication and it overwrites the DR note set during reseeding.

Failback does not copy DR writes back to primary. It only restores routing and, for EC2, starts the
primary instance. Production failback would require a write freeze plus an approved reverse
database migration/reconciliation process. This lab intentionally demonstrates and documents that
limitation.

Separate infrastructure backups exist for EC2/RDS:

- AWS Backup is scheduled daily at `02:00 UTC` with 30-day retention by default;
- RDS automated backups have one-day retention and a `03:00-04:00 UTC` backup window;
- the current primary pipeline does not set the optional cross-Region backup-vault ARN, so the code
  must not be presented as continuously copying those scheduled backups to Singapore;
- these recovery points are not automatically restored by DR 2 and are not used for reverse
  synchronization during failback.

The EKS drill currently has no Velero, pgBackRest, continuous WAL archive, or scheduled EKS database
backup implementation. Its implemented recovery mechanism is the explicit API snapshot/reseed step.

### Failover to DR

Use confirmation `DEMONSTRATE_DR`.

#### EKS

The workflow validates the direct DR endpoint, reads its DR ALB DNS hostname from
`eks-dr.dr.vaultrix.in`, and reads the ALB DNS hostname currently behind `eks.dr.vaultrix.in`.

An "ALB target" here means the AWS-generated DNS hostname of an Application Load Balancer, for
example `k8s-notes-notes-...ap-south-1.elb.amazonaws.com`. It is not a Pod IP and not a shared object
between Regions. Mumbai and Singapore have different ALBs and therefore different target hostnames.

Before cutover, the workflow saves the Mumbai hostname as `eks-primary.dr.vaultrix.in`. That stable
diagnostic record is a bookmark used during failback. It then changes the public
`eks.dr.vaultrix.in` CNAME to the different Singapore hostname already recorded at
`eks-dr.dr.vaultrix.in`.

EKS cutover is manual and approval-gated. CloudWatch does not initiate it. The primary EKS cluster
continues running because an EKS control plane cannot be stopped like an EC2 instance.

#### EC2

The workflow validates Singapore, stops only the primary EC2 application instance, and waits for the
Route 53 primary health check to fail. Route 53 then automatically selects the healthy SECONDARY
record pointing to Singapore. The workflow confirms the normal status endpoint reports
`environment=DR` and `database=connected`.

CloudWatch alarms provide monitoring and SNS notification only. They do not dispatch either DR
workflow. EC2 routing automation is implemented by Route 53 health checks, not CloudWatch.

### Availability Zone versus Region failure

The DR workflows move service between Mumbai and Singapore; they do not accept an Availability Zone
input. Regional ALBs and networks span two AZs, and the EKS node group consumes two private subnets.
AWS handles available in-Region capacity through those regional services.

An isolated EKS node/AZ failure does not automatically change `eks.dr.vaultrix.in` to Singapore.
The regional ALB stops sending requests to unhealthy targets, while the EKS scheduler can run or
replace stateless application Pods on healthy nodes in the second Mumbai AZ. That second AZ is the
normal in-Region recovery path and prevents every single-AZ fault from becoming a regional DR event.
The operator invokes DR 2 failover only if the application remains unhealthy or the drill is meant
to demonstrate a regional evacuation.

The EC2 application itself is one instance and RDS is Single-AZ. If an instance or AZ problem makes
the primary endpoint unhealthy, Route 53 can still select Singapore because it responds to endpoint
health, not the cause of failure. EKS has a multi-subnet/node layout, but its single PostgreSQL EBS
volume remains AZ-bound and is not a production-grade HA database.

The demo does not and cannot shut down an entire AWS Region. It demonstrates a real EC2 application
failure by stopping the primary instance and a controlled EKS regional evacuation by changing DNS.

### Workflow implementation layout

The workflow YAML intentionally shows orchestration, approvals, credentials, and named recovery
steps rather than embedding long shell programs:

- `.github/actions/dr-drill/action.yml` gives workflow steps a small composite-action interface and
  forwards named operations and outputs without embedding Bash in workflow YAML;
- `.github/scripts/dr-drill.sh` implements the Linux commands used by that composite action to
  prepare, validate, cut over, fail back, and remove DR application resources;
- `.github/actions/terraform-init/action.yml` is the composite action that consistently initializes
  each isolated Terraform state;
- `.github/workflows/dr-drill.yml` and `dr-platform.yml` remain the readable control plane.

Keeping operational commands in one strict-mode Bash script makes them syntax-checkable and avoids
duplicating retry, DNS, and validation logic without hiding environment approval boundaries.
`CI - Terraform` runs a Bash syntax check for repository workflow scripts on every relevant pull
request.

### Failback to primary

Use confirmation `DEMONSTRATE_DR` only after confirming primary dependencies are available.

- EKS failback does not recreate or start primary infrastructure. It expects primary EKS, its
  workload, database, and ALB to be healthy, then restores `eks.dr.vaultrix.in` from the hostname
  saved in `eks-primary.dr.vaultrix.in`.
- EC2 failback expects the primary ALB, RDS, networking, and Terraform stack to remain present. The
  workflow starts the deliberately stopped primary EC2 instance. When its health check recovers,
  Route 53 automatically prefers the PRIMARY record again.

The single `Failback to primary` dispatch starts both the EKS and EC2 failback jobs. Each has its own
protected environment gate. It is application/drill orchestration over already-existing primary
infrastructure, not a Terraform rebuild of the primary Region.

DR 1 is infrastructure-oriented. DR 2 is application and drill-oriented, although it necessarily
touches DNS and the EC2 instance power state to demonstrate recovery.

### Remove DR applications

This operation is intentionally not called Terraform destroy. It uses `kubectl delete` and
`helm uninstall` to remove the DR EKS workload, PostgreSQL volume, EKS-created ALB, controller, and
EKS diagnostic records. It does not destroy the EKS cluster or the Terraform-managed EC2/RDS stack.

After failback and application removal, use DR 1 `Apply destroy` for EKS, EC2, and finally shared
egress.

## Demonstration checklist

1. Confirm the normal URLs report primary and create clearly named marker data.
2. Run DR 1 `Apply deploy` for EKS and EC2 if their infrastructure is absent. Either selection
   automatically ensures shared egress first.
3. Run DR 2 `Deploy or refresh DR applications` to establish the recovery point.
4. Validate `eks-dr.dr.vaultrix.in` and `ec2-dr.dr.vaultrix.in`.
5. Run DR 2 `Failover to DR` with `DEMONSTRATE_DR`.
6. Show EKS DNS cutover and EC2 Route 53 health-check failover.
7. Write `Written during DR` data and explain that the lab does not merge it back.
8. Confirm primary dependencies, then run `Failback to primary` with `DEMONSTRATE_DR`.
9. Verify normal endpoints serve Mumbai again.
10. Optionally remove DR applications and destroy temporary DR infrastructure in dependency order.

## What `terraform_matrix.py` does

`.github/scripts/terraform_matrix.py` is a CI selector. It reads changed file paths from standard
input and prints a compact JSON GitHub Actions matrix containing only affected Terraform roots.

Examples:

- changing `terraform/modules/eks-platform` selects primary and DR EKS roots;
- changing an EC2/RDS/ALB/backup module selects primary and DR EC2 roots;
- changing a regional-network module selects primary and DR shared roots;
- changing `terraform-pr.yml` or the matrix script itself selects every root.

`CI - Terraform` uses the matrix to run formatting, initialization, and validation only where needed.
It also derives whether the primary EKS or EC2 speculative plan jobs are needed. The script does not
create, change, or destroy AWS resources.
