locals {
  project          = "vaultrix-dr"
  environment      = "primary"
  application      = "ec2"
  contract_version = "1.0.0"
  name_prefix      = "${local.project}-${local.environment}-${local.application}"

  # Consumed primary shared outputs (strictly allowed by shared contract)
  shared_vpc_id              = data.terraform_remote_state.primary_shared.outputs.vpc_id
  shared_vpc_cidr_block      = data.terraform_remote_state.primary_shared.outputs.vpc_cidr_block
  shared_public_subnet_ids   = data.terraform_remote_state.primary_shared.outputs.public_subnet_ids
  shared_ec2_private_subnets = data.terraform_remote_state.primary_shared.outputs.ec2_private_subnet_ids
  shared_database_subnets    = data.terraform_remote_state.primary_shared.outputs.database_subnet_ids
  shared_common_tags         = data.terraform_remote_state.primary_shared.outputs.common_tags

  # Consumed global shared outputs (strictly allowed by shared contract)
  global_route53_zone_id   = data.terraform_remote_state.global_shared.outputs.route53_zone_id
  global_route53_zone_name = data.terraform_remote_state.global_shared.outputs.route53_zone_name
  global_github_ec2_role   = data.terraform_remote_state.global_shared.outputs.github_ec2_role_arn

  common_tags = merge(
    local.shared_common_tags,
    {
      Application = local.application
      Owner       = "gokulk18"
    }
  )
}
