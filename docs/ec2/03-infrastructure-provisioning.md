# 03. Infrastructure Provisioning with Terraform — Comprehensive Notes

## 1. Overview & Remote Backend Architecture

All AWS infrastructure for the VaultRix EC2 application is declared using Terraform 1.15.8 and modularized under `terraform/modules/`. State is isolated across regional and global backend keys stored in S3 with state locking managed by S3 lockfiles.

```
+---------------------------------------------------------------------------------------+
|                                TERRAFORM STATE BOUNDARIES                             |
+--------------------------+--------------------+---------------------------------------+
| Environment              | State File Key     | Responsibilities                      |
+--------------------------+--------------------+---------------------------------------+
| Global Shared            | global/shared/...  | Route 53 Hosted Zone (dr.vaultrix.in),|
|                          |                    | GitHub OIDC IAM Roles                 |
+--------------------------+--------------------+---------------------------------------+
| Primary Shared           | primary/shared/... | Primary VPC (10.10.0.0/16), Subnets,  |
| (ap-south-1)             |                    | Gateway Endpoints, NAT Egress         |
+--------------------------+--------------------+---------------------------------------+
| Primary EC2 Workload     | primary/ec2/...    | Primary ALB, EC2 Instance, RDS DB,    |
| (ap-south-1)             |                    | Backup Vault & Plan, Route 53 PRIMARY |
+--------------------------+--------------------+---------------------------------------+
| DR Shared                | dr/shared/...      | DR VPC (10.20.0.0/16), Subnets,       |
| (ap-southeast-1)         |                    | Gateway Endpoints, NAT Egress         |
+--------------------------+--------------------+---------------------------------------+
| DR EC2 Workload          | dr/ec2/...         | DR ALB, DR EC2 Instance, DR RDS DB,   |
| (ap-southeast-1)         |                    | Backup Vault, Route 53 SECONDARY      |
+--------------------------+--------------------+---------------------------------------+
```

---

## 2. Remote State Dependencies in Workload Roots

The EC2 workload root (`terraform/environments/primary/ec2/main.tf` and `terraform/environments/dr/ec2/main.tf`) consumes network and global configuration via `data "terraform_remote_state"` blocks:

```hcl
# Read primary shared network infrastructure state
data "terraform_remote_state" "primary_shared" {
  backend = "s3"

  config = {
    bucket       = var.state_bucket
    key          = "primary/shared/terraform.tfstate"
    region       = var.state_region
    use_lockfile = true
  }
}

# Read global shared infrastructure state (Route 53 zone & OIDC roles)
data "terraform_remote_state" "global_shared" {
  backend = "s3"

  config = {
    bucket       = var.state_bucket
    key          = "global/shared/terraform.tfstate"
    region       = var.state_region
    use_lockfile = true
  }
}
```

### Consumed Variables Mapping (`locals.tf`)
- `shared_vpc_id`: Consumed VPC ID from `primary_shared` output `vpc_id`.
- `shared_public_subnet_ids`: Consumed public subnet IDs for ALB placement.
- `ec2_subnet_id`: First private subnet ID (`local.shared_ec2_private_subnets[0]`) for EC2 compute placement.
- `shared_database_subnets`: Private database subnet IDs for `aws_db_subnet_group`.
- `global_route53_zone_id` & `global_route53_zone_name`: Route 53 Hosted Zone details for domain `dr.vaultrix.in`.

---

## 3. Terraform Module Parameterization

### A. EC2 Compute Module (`terraform/modules/ec2`)
- **Main Config**: [`main.tf`](file:///c:/Users/smine/Disaster-Recovery/terraform/modules/ec2/main.tf)
- **Variables**: [`variables.tf`](file:///c:/Users/smine/Disaster-Recovery/terraform/modules/ec2/variables.tf)
- **Outputs**: [`outputs.tf`](file:///c:/Users/smine/Disaster-Recovery/terraform/modules/ec2/outputs.tf)

```hcl
module "ec2" {
  source = "../../../modules/ec2"

  name_prefix                = local.name_prefix
  vpc_id                     = local.shared_vpc_id
  subnet_id                  = local.ec2_subnet_id
  ingress_security_group_ids = [module.alb.security_group_id]
  app_port                   = 8080
  app_image                  = var.app_image
  app_env                    = "PRIMARY"
  db_secret_arn              = module.rds.secret_arn
  enable_db_secret_access    = true
  common_tags                = local.common_tags
}
```

---

### B. Application Load Balancer Module (`terraform/modules/alb`)
- **Main Config**: [`main.tf`](file:///c:/Users/smine/Disaster-Recovery/terraform/modules/alb/main.tf)

```hcl
module "alb" {
  source = "../../../modules/alb"

  name_prefix       = local.name_prefix
  vpc_id            = local.shared_vpc_id
  public_subnet_ids = local.shared_public_subnet_ids
  app_port          = 8080
  health_check_path = "/health"
  common_tags       = local.common_tags
}
```

---

### C. RDS PostgreSQL Module (`terraform/modules/rds`)
- **Main Config**: [`main.tf`](file:///c:/Users/smine/Disaster-Recovery/terraform/modules/rds/main.tf)

```hcl
module "rds" {
  source = "../../../modules/rds"

  name_prefix         = local.name_prefix
  vpc_id              = local.shared_vpc_id
  database_subnet_ids = local.shared_database_subnets
  db_name             = "appdb"
  db_username         = "dbadmin"
  common_tags         = local.common_tags
}
```

---

### D. AWS Backup Module (`terraform/modules/aws-backup`)
- **Main Config**: [`main.tf`](file:///c:/Users/smine/Disaster-Recovery/terraform/modules/aws-backup/main.tf)

```hcl
module "aws_backup" {
  source = "../../../modules/aws-backup"

  name_prefix                       = local.name_prefix
  backup_schedule                   = var.backup_schedule
  backup_retention_days             = var.backup_retention_days
  copy_action_destination_vault_arn = var.copy_action_destination_vault_arn
  selection_resources = [
    module.ec2.instance_arn,
    module.rds.db_instance_arn
  ]
  common_tags = local.common_tags
}
```

---

## 4. GitHub Actions Infrastructure Workflow (`.github/workflows/ec2-platform.yml`)

The workflow manages automated planning and execution of Terraform for the primary EC2 workload.

```yaml
name: Primary 3 - EC2 infrastructure

on:
  workflow_dispatch:
    inputs:
      operation:
        description: Plan is read-only; Apply creates or updates the cost-bearing primary platform
        required: true
        type: choice
        options: [Plan, Apply]

permissions:
  contents: read
  id-token: write

env:
  TF_IN_AUTOMATION: "true"
  TF_INPUT: "false"
  TF_ROOT: terraform/environments/primary/ec2
```

### Execution Flow:
1. **Plan Job**:
   - Assumes AWS OIDC role `vars.AWS_EC2_PLAN_ROLE_ARN` in region `ap-south-1`.
   - Runs `terraform init` configuring S3 backend.
   - Runs `terraform plan -lock=false -out=phase7b.tfplan -var="expected_aws_account_id=598120810297" -var="cost_acknowledgement=APPROVE_PRIMARY_EC2_COSTS"`.
   - Uploads binary plan `phase7b.tfplan` and text plan `phase7b-plan.txt` as workflow artifacts.
2. **Apply Job**:
   - Triggers only when `inputs.operation == 'Apply'`.
   - Environment: `ec2-apply` (requires explicit reviewer approval).
   - Assumes AWS OIDC role `vars.AWS_EC2_APPLY_ROLE_ARN`.
   - Downloads exact artifact `phase7b.tfplan`.
   - Runs `terraform apply -auto-approve phase7b.tfplan`.
