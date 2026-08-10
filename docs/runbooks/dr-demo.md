# Minimal EKS and EC2 Disaster Recovery Demonstration

This drill demonstrates recovery from Mumbai (`ap-south-1`) into temporary Singapore (`ap-southeast-1`) infrastructure. It is intentionally simple and must not be presented as production-grade continuous replication.

## What the drill proves

- Shared Singapore networking is reused by both workload owners.
- Temporary private egress, EKS, EC2, RDS, and ALBs are created only for the drill.
- The same public GHCR application images run in both Regions.
- A drill-time logical snapshot copies current EKS notes and EC2 tasks into the DR databases.
- EC2 uses Route 53 health-check failover after the primary instance is stopped.
- EKS uses an approved Route 53 cutover because an EKS control plane cannot be stopped.
- Failback returns both names to Mumbai and cleanup removes temporary DR resources.

The recovery point is the time **DR 2 - Drill** runs `Deploy or refresh DR applications` and captures the APIs. Writes made after that capture are outside this demonstration's RPO.

## One-time preparation before the meeting

In GitHub, open **Actions** and run **DR 1 - Infrastructure** against `main` in this order:

1. `component=shared-egress`, `operation=Apply deploy`.
2. `component=eks`, `operation=Apply deploy`.
3. `component=ec2`, `operation=Apply deploy`.
4. Run **DR 2 - Drill** with `operation=Deploy or refresh DR applications`.

Review and approve each protected environment only after its plan summary matches the expected scope. Preparation is complete when all four workflows pass and these diagnostic endpoints work:

```text
http://eks-dr.dr.vaultrix.in/healthz
http://eks-dr.dr.vaultrix.in/api/notes
http://ec2-dr.dr.vaultrix.in/health
http://ec2-dr.dr.vaultrix.in/api/status
```

## What to show the team

### 1. Establish the primary baseline

Open:

```text
http://eks.dr.vaultrix.in
http://ec2.dr.vaultrix.in
```

Create one clearly named item in each application, such as `Before DR drill`. Explain that Mumbai is currently authoritative.

If those items were created after the preparation snapshot, rerun **DR 2 - Drill** with `operation=Deploy or refresh DR applications` before failover so they are included in the recovery point.

### 2. Show the prepared recovery environment

Open the diagnostic endpoints:

```text
http://eks-dr.dr.vaultrix.in
http://ec2-dr.dr.vaultrix.in
```

Show that the copied notes/tasks are present. In the EC2 status API, point out:

```json
{"environment":"DR","database":"connected"}
```

### 3. Declare and execute failover

Run **DR 2 - Drill** with:

```text
operation=Failover to DR
confirmation=DEMONSTRATE_DR
```

Approve the `eks-apply` and `ec2-apply` gates.

Explain what happens:

- EKS validates Singapore and changes `eks.dr.vaultrix.in` to the DR ALB.
- EC2 validates Singapore, stops only the primary EC2 instance, and waits for Route 53 to select the healthy SECONDARY record automatically.
- Primary RDS and primary EKS remain intact.

Refresh the normal application URLs. Both now serve from Singapore. For EC2, `/api/status` must show `environment=DR` and `database=connected`.

### 4. Prove DR writes

Create one item in each normal application URL named `Written during DR`. Refresh and show it persists in the Singapore databases.

State the important limitation: this minimal drill does not merge DR-time writes back into Mumbai. Production failback requires a write fence and database reconciliation.

### 5. Execute failback

Run **DR 2 - Drill** with:

```text
operation=Failback to primary
confirmation=DEMONSTRATE_DR
```

The workflow restores the EKS CNAME and starts the primary EC2 instance. Route 53 automatically returns EC2 traffic after the primary ALB health check recovers.

Verify:

```text
http://eks.dr.vaultrix.in/healthz
http://ec2.dr.vaultrix.in/api/status
```

The EC2 response must again show `environment=PRIMARY` and `database=connected`.

## Cleanup after the demonstration

Run these only after failback succeeds:

1. **DR 2 - Drill**: `operation=Remove DR applications`, confirmation `CLEANUP_DR_APPS`.
2. **DR 1 - Infrastructure**: `component=eks`, `operation=Apply cleanup`.
3. **DR 1 - Infrastructure**: `component=ec2`, `operation=Apply cleanup`.
4. **DR 1 - Infrastructure**: `component=shared-egress`, `operation=Apply cleanup`.

Finish by running read-only cleanup plans for all three components. Each must report `No changes` with deployment disabled/cleanup selected.

## Short presentation script

> Mumbai hosts both primary applications. Singapore retains only shared networking until a disaster is declared. We create temporary recovery compute from the same Terraform modules and deploy the same immutable GHCR images. At the recovery point, application data is copied into isolated Singapore databases. We validate DR before changing traffic. EC2 demonstrates health-check-driven DNS failover after its primary instance stops; EKS uses an explicit approved DNS cutover because managed EKS control planes cannot be paused. After validation, we fail back and destroy temporary Singapore compute to control cost.
