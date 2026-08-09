# Primary EC2 Read-Only Shared Foundation Consumer Proof

Phase 6 consumer proof root for the `@gokulk18` (EC2/RDS) ownership boundary in `ap-south-1` (Mumbai).

## Overview

This Terraform root proves that the primary EC2 stack can read outputs from `primary/shared` and `global/shared` via `data.terraform_remote_state` without creating, modifying, or managing any shared or workload resources.

## State Boundary

* **State Key**: `primary/ec2/terraform.tfstate`
* **Owner**: `@gokulk18` (EC2/RDS Owner)
* **Access Mode**: Read-only consumption of `primary/shared` and `global/shared`.

## Consumed Shared Contract Outputs

* `primary/shared`: `vpc_id`, `vpc_cidr_block`, `public_subnet_ids`, `ec2_private_subnet_ids`, `database_subnet_ids`, `common_tags`
* `global/shared`: `route53_zone_id`, `route53_zone_name`, `github_ec2_role_arn`

## Usage

```bash
terraform init -backend-config=backend.hcl.example
terraform validate
terraform plan
```
