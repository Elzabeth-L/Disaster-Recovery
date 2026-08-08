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

# Internet-Facing Application Load Balancer Module
module "alb" {
  source = "../../../modules/alb"

  name_prefix        = local.name_prefix
  vpc_id             = local.shared_vpc_id
  public_subnet_ids  = local.shared_public_subnet_ids
  target_instance_id = module.ec2.instance_id
  app_port           = 8080
  health_check_path  = "/health"
  common_tags        = local.common_tags
}

# Primary Private RDS PostgreSQL Instance Module
module "rds" {
  source = "../../../modules/rds"

  name_prefix              = local.name_prefix
  vpc_id                   = local.shared_vpc_id
  database_subnet_ids      = local.shared_database_subnets
  source_security_group_id = module.ec2.security_group_id
  db_name                  = "appdb"
  db_username              = "dbadmin"
  common_tags              = local.common_tags
}

# Primary EC2 Compute Instance Module (Protected inside private subnet, trusting ALB SG & reading RDS secret)
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
  common_tags                = local.common_tags
}

# AWS Backup Foundation Module (Protecting Primary EC2 Instance & Private RDS Database)
module "aws_backup" {
  source = "../../../modules/aws-backup"

  name_prefix           = local.name_prefix
  backup_schedule       = var.backup_schedule
  backup_retention_days = var.backup_retention_days
  selection_resources = [
    module.ec2.instance_arn,
    module.rds.db_instance_arn
  ]
  common_tags = local.common_tags
}
