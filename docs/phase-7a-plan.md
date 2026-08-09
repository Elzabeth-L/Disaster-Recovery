# Phase 7A - Primary EKS and notes application

Status: implementation prepared; AWS apply not yet approved or executed.

## Selected design

- EKS Kubernetes `1.35`, which remains in standard support through 2027-03-27.
- One continuously available primary control plane in Mumbai and no DR cluster in this phase.
- Two `t4g.small` on-demand managed nodes across the two existing private EKS subnets. The original
  `t4g.medium` plan was rejected at instance launch because this account enforces Free Tier-eligible
  EC2 types. `t4g.small` is the largest eligible ARM64 type reported in Mumbai; `t4g.micro` is too
  small for EKS system pods plus the application and PostgreSQL requests.
- Existing `t4g.micro` NAT instance for private-node egress. A NAT Gateway remains only the fallback
  if node registration, ECR pulls, STS, controller calls, or package access prove unreliable.
- EKS Pod Identity for VPC CNI, EBS CSI, and AWS Load Balancer Controller. The node role also retains
  the CNI policy so networking can bootstrap before Pod Identity agents become ready.
- AWS-managed EKS add-ons selected at plan time for the chosen Kubernetes minor.
- ECR with immutable tags and scan-on-push; Secrets Manager owns the database credential value.
- Two notes application replicas and one PostgreSQL StatefulSet backed by an encrypted 8 GiB gp3
  PVC. PostgreSQL is cluster-internal and has no LoadBalancer or public endpoint.
- One internet-facing ALB. `eks.dr.vaultrix.in` is created only after the ALB health check succeeds.

The EKS API has a public endpoint because GitHub-hosted runners use changing public addresses. It is
also privately reachable, Kubernetes access is restricted through EKS access entries, and only the
protected EKS apply role receives cluster administrator access. A private-only endpoint requires a
self-hosted runner or another fixed private execution path and is deferred.

## Cost gate

This is not a free-tier stack. The standard-support EKS control plane alone is approximately
`$0.10/hour`, or `$73` in a 730-hour month. Two nodes, their root volumes, the PostgreSQL volume, an
ALB, public IPv4, logs, NAT-instance egress, and data transfer are additional. A planning range of
roughly `$145-$180/month` before traffic is intentionally conservative and must be replaced with an
AWS Pricing Calculator estimate for Mumbai before apply.

The Terraform root creates nothing by default. Both of these inputs are required to show the
cost-bearing resources in a plan:

```text
deployment_enabled=true
cost_acknowledgement=APPROVE_PRIMARY_EKS_COSTS
```

Cluster deletion protection and ALB deletion protection are enabled by default. If measured cost is
unacceptable, use the documented backup-first cleanup procedure to destroy and recreate the primary
platform before demonstrations. The DR cluster remains absent until a declared drill/disaster.

## Delivery and acceptance gates

1. Apply the reviewed, no-hourly-cost GitHub EKS role permission update in `global/shared`.
2. Merge this implementation only after Terraform validation, app tests, ARM64 image build, manifest
   rendering, and a speculative EKS plan pass.
3. Review the exact resource count, add-on versions, quota checks, and Pricing Calculator estimate.
4. Obtain explicit approval before dispatching `Primary EKS platform` with `Apply`.
5. Verify control plane, two nodes, all add-ons, Pod Identity associations, NAT egress, ECR pull, and
   EBS dynamic provisioning.
6. Dispatch the protected application workflow; verify PostgreSQL and both app replicas, CRUD data,
   pod recreation persistence, ALB health, and DNS.
7. Record resource IDs, observed monthly run rate, test evidence, and any cleanup date.

Phase 7A is accepted only after those live checks. Terraform/configuration completion by itself is not
acceptance.
