# DR Shared Network

Phase 3 composes the reusable regional-network module for the Singapore pilot light. It owns only shared networking. It must not create NAT, EKS, EC2 application, RDS, ALB, DNS, or IAM resources.

## Planned topology

- VPC: `10.20.0.0/16`
- Two standard Availability Zones selected deterministically by AZ ID
- Eight `/24` subnets: public, EC2 private, EKS private, and database in each AZ
- Internet routes only on the two public route tables
- Free S3 gateway endpoint on all six private route tables
- No NAT instance, NAT Gateway, Elastic IP, compute, or general private egress

Recovery workflows may create an approved temporary egress path later and must remove it during cleanup. The Phase 3 shared root intentionally fixes `egress_mode` to `none` rather than accepting an override.

## Plan workflow

```powershell
Copy-Item backend.hcl.example backend.hcl
Copy-Item terraform.tfvars.example terraform.tfvars
# Replace the account ID, backend bucket, and owner placeholders.
terraform init -backend-config=backend.hcl
terraform fmt -check
terraform validate
terraform plan -out phase-3.tfplan
```

Backend configuration, variable values, plans, state, and credentials remain ignored. Root use is an explicit owner decision for this lab; it is never persisted in Terraform or GitHub. A plan does not authorize an apply.
