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

# Primary EC2 Compute Instance Module (Protected inside private subnet, trusting ALB SG)
module "ec2" {
  source = "../../../modules/ec2"

  name_prefix                = local.name_prefix
  vpc_id                     = local.shared_vpc_id
  subnet_id                  = local.ec2_subnet_id
  ingress_security_group_ids = [module.alb.security_group_id]
  app_port                   = 8080
  common_tags                = local.common_tags
}
