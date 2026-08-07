# Primary Shared Network

Phase 2 composes the reusable regional-network module for Mumbai. It owns only shared networking and egress. It must not create EKS, EC2 application, RDS, ALB, DNS, or DR resources.

## Planned topology

- VPC: `10.10.0.0/16`
- Two standard Availability Zones selected deterministically by AZ ID
- Eight `/24` subnets: public, EC2 private, EKS private, and database in each AZ
- No Internet default route for database subnets
- Free S3 gateway endpoint on all private route tables
- Default egress: one AL2023 `t4g.nano` NAT instance in the first public subnet
- Explicit fallbacks: one zonal NAT Gateway or no general private egress

The NAT instance has no inbound administration rule, requires IMDSv2, disables source/destination checking, uses encrypted gp3 storage, and runs with standard CPU credits to avoid unlimited-credit charges. It is intentionally single-AZ and must pass EKS node registration, ECR/image-pull, STS, controller, and package-repository tests before Phase 7A. If it is unreliable, change `egress_mode` to `nat_gateway`, review the new plan/cost, and apply only after approval.

## Plan workflow

```powershell
Copy-Item backend.hcl.example backend.hcl
Copy-Item terraform.tfvars.example terraform.tfvars
# Replace the account ID and owner placeholders.
terraform init -backend-config=backend.hcl
terraform fmt -check
terraform validate
terraform plan -out phase-2.tfplan
```

Backend configuration, variable values, plans, state, and credentials remain ignored. Root use is an explicit owner decision for this lab; it is never persisted in Terraform or GitHub. A plan does not authorize an apply.
