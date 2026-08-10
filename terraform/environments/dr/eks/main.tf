data "terraform_remote_state" "dr_shared" {
  backend = "s3"
  config = {
    bucket       = var.state_bucket
    key          = "dr/shared/terraform.tfstate"
    region       = var.state_region
    use_lockfile = true
  }
}

data "terraform_remote_state" "global_shared" {
  backend = "s3"
  config = {
    bucket       = var.state_bucket
    key          = "global/shared/terraform.tfstate"
    region       = var.state_region
    use_lockfile = true
  }
}

check "shared_contract" {
  assert {
    condition = (
      data.terraform_remote_state.dr_shared.outputs.contract_version == local.contract_version &&
      data.terraform_remote_state.global_shared.outputs.contract_version == local.contract_version
    )
    error_message = "DR and global shared states must expose contract version 1.0.0."
  }
}

module "eks_platform" {
  count  = var.deployment_enabled ? 1 : 0
  source = "../../../modules/eks-platform"

  name_prefix           = local.name_prefix
  kubernetes_version    = var.kubernetes_version
  private_subnet_ids    = data.terraform_remote_state.dr_shared.outputs.eks_private_subnet_ids
  github_apply_role_arn = data.terraform_remote_state.global_shared.outputs.github_eks_role_arn
  eks_operator_user_arn = "arn:aws:iam::${var.expected_aws_account_id}:user/vaultrix-dr-eks-operator"
  deletion_protection   = false
  node_instance_types   = ["t4g.small"]
  node_desired_size     = 2
  tags                  = local.common_tags
}
