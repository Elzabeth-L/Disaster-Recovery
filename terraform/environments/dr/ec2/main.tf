# Read DR shared network infrastructure state
data "terraform_remote_state" "dr_shared" {
  backend = "s3"

  config = {
    bucket       = var.state_bucket
    key          = "dr/shared/terraform.tfstate"
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

# DR Internet-Facing Application Load Balancer Module
module "alb" {
  source = "../../../modules/alb"

  name_prefix       = local.name_prefix
  vpc_id            = local.shared_vpc_id
  public_subnet_ids = local.shared_public_subnet_ids
  app_port          = 8080
  health_check_path = "/health"
  common_tags       = local.common_tags
}

# DR Private RDS PostgreSQL Instance Module
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

# DR EC2 Compute Instance Module (Protected inside private subnet, trusting ALB SG & reading DR RDS secret)
module "ec2" {
  source = "../../../modules/ec2"

  name_prefix                = local.name_prefix
  vpc_id                     = local.shared_vpc_id
  subnet_id                  = local.ec2_subnet_id
  ingress_security_group_ids = [module.alb.security_group_id]
  app_port                   = 8080
  app_image                  = var.app_image
  app_env                    = "DR"
  db_secret_arn              = module.rds.secret_arn
  enable_db_secret_access    = true
  common_tags                = local.common_tags
}

# DR AWS Backup Vault & Plan Module (in ap-southeast-1)
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

# CloudWatch Alarms: ALB, EC2, and RDS health & performance monitoring in DR region
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

# Route 53 Health Check for DR EC2 ALB Health Endpoint (/health)
resource "aws_route53_health_check" "dr_ec2" {
  fqdn              = module.alb.alb_dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/health"
  request_interval  = 30
  failure_threshold = 3

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-dr-alb-health-check"
    }
  )
}

# Route 53 Secondary Failover Alias Record (ec2.dr.vaultrix.in -> DR ALB)
resource "aws_route53_record" "dr_ec2_alias" {
  zone_id = local.global_route53_zone_id
  name    = "ec2.${local.global_route53_zone_name}"
  type    = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier  = "SECONDARY"
  health_check_id = aws_route53_health_check.dr_ec2.id

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

# Stable diagnostic endpoint used to validate DR before traffic cutover.
resource "aws_route53_record" "dr_ec2_diagnostic" {
  zone_id = local.global_route53_zone_id
  name    = "ec2-dr.${local.global_route53_zone_name}"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}
