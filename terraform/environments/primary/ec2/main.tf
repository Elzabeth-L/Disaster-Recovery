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

  name_prefix       = local.name_prefix
  vpc_id            = local.shared_vpc_id
  public_subnet_ids = local.shared_public_subnet_ids
  app_port          = 8080
  health_check_path = "/health"
  common_tags       = local.common_tags
}

# Primary Private RDS PostgreSQL Instance Module
module "rds" {
  source = "../../../modules/rds"

  name_prefix         = local.name_prefix
  vpc_id              = local.shared_vpc_id
  database_subnet_ids = local.shared_database_subnets
  db_name             = "appdb"
  db_username         = "dbadmin"
  common_tags         = local.common_tags
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = module.alb.target_group_arn
  target_id        = module.ec2.instance_id
  port             = 8080
}

resource "aws_security_group_rule" "rds_ingress_ec2" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = module.ec2.security_group_id
  security_group_id        = module.rds.security_group_id
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
  enable_db_secret_access    = true
  common_tags                = local.common_tags
}

# AWS Backup Foundation Module (Protecting Primary EC2 Instance & Private RDS Database)
# cross-region copy to DR vault ensures RPO < 26h for DR data continuity
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

# CloudWatch Alarms: ALB, EC2, and RDS health & performance monitoring
module "cloudwatch_alarms" {
  source = "../../../modules/cloudwatch-alarms"

  name_prefix             = local.name_prefix
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  ec2_instance_id         = module.ec2.instance_id
  rds_identifier          = module.rds.db_instance_identifier
  alarm_email             = var.alarm_email
  common_tags             = local.common_tags
}

# Route 53 Health Check for Primary EC2 ALB Health Endpoint (/health)
resource "aws_route53_health_check" "primary_ec2" {
  fqdn              = module.alb.alb_dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/health"
  request_interval  = 30
  failure_threshold = 3

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-primary-alb-health-check"
    }
  )
}

# Route 53 Primary Failover Alias Record (ec2.dr.vaultrix.in -> Primary ALB)
resource "aws_route53_record" "primary_ec2_alias" {
  zone_id = local.global_route53_zone_id
  name    = "ec2.${local.global_route53_zone_name}"
  type    = "A"

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier  = "PRIMARY"
  health_check_id = aws_route53_health_check.primary_ec2.id

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

