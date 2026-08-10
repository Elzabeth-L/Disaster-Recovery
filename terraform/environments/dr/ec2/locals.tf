locals {
  contract_version = "1.0.0"

  raw_dr_shared_outputs     = data.terraform_remote_state.dr_shared.outputs
  raw_global_shared_outputs = data.terraform_remote_state.global_shared.outputs

  dr_shared_contract_version     = try(local.raw_dr_shared_outputs.contract_version, "")
  global_shared_contract_version = try(local.raw_global_shared_outputs.contract_version, "")

  valid_dr_contract     = local.dr_shared_contract_version == local.contract_version
  valid_global_contract = local.global_shared_contract_version == local.contract_version

  shared_vpc_id              = local.valid_dr_contract ? local.raw_dr_shared_outputs.vpc_id : ""
  shared_vpc_cidr_block      = local.valid_dr_contract ? local.raw_dr_shared_outputs.vpc_cidr_block : ""
  shared_public_subnet_ids   = local.valid_dr_contract ? local.raw_dr_shared_outputs.public_subnet_ids : []
  shared_ec2_private_subnets = local.valid_dr_contract ? local.raw_dr_shared_outputs.ec2_private_subnet_ids : []
  shared_database_subnets    = local.valid_dr_contract ? local.raw_dr_shared_outputs.database_subnet_ids : []

  global_route53_zone_id   = local.valid_global_contract ? local.raw_global_shared_outputs.route53_zone_id : ""
  global_route53_zone_name = local.valid_global_contract ? local.raw_global_shared_outputs.route53_zone_name : ""
  global_github_ec2_role   = local.valid_global_contract ? local.raw_global_shared_outputs.github_ec2_role_arn : ""

  ec2_subnet_id = length(local.shared_ec2_private_subnets) > 0 ? local.shared_ec2_private_subnets[0] : ""

  name_prefix = "vaultrix-dr-dr-ec2"

  common_tags = {
    Project              = "vaultrix-dr"
    Environment          = "dr"
    ManagedBy            = "terraform"
    Ownership            = "ec2"
    ContractVersion      = local.contract_version
    Expiration           = "temporary-dr-drill"
    DisasterRecoveryRole = "standby"
  }
}

check "dr_shared_contract_version" {
  assert {
    condition     = local.valid_dr_contract
    error_message = "The dr/shared state must expose contract_version = \"1.0.0\"."
  }
}

check "global_shared_contract_version" {
  assert {
    condition     = local.valid_global_contract
    error_message = "The global/shared state must expose contract_version = \"1.0.0\"."
  }
}
