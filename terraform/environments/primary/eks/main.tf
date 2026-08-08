data "terraform_remote_state" "primary_shared" {
  backend = "s3"
  config = {
    bucket       = var.state_bucket
    key          = "primary/shared/terraform.tfstate"
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
      data.terraform_remote_state.primary_shared.outputs.contract_version == local.contract_version &&
      data.terraform_remote_state.global_shared.outputs.contract_version == local.contract_version
    )
    error_message = "Primary and global shared states must expose contract version 1.0.0."
  }
}

check "cost_gate" {
  assert {
    condition     = !var.deployment_enabled || var.cost_acknowledgement == "APPROVE_PRIMARY_EKS_COSTS"
    error_message = "Set cost_acknowledgement to APPROVE_PRIMARY_EKS_COSTS when enabling this cost-bearing platform."
  }
}

module "eks_platform" {
  count  = var.deployment_enabled ? 1 : 0
  source = "../../../modules/eks-platform"

  name_prefix           = local.name_prefix
  kubernetes_version    = var.kubernetes_version
  private_subnet_ids    = data.terraform_remote_state.primary_shared.outputs.eks_private_subnet_ids
  github_apply_role_arn = data.terraform_remote_state.global_shared.outputs.github_eks_role_arn
  deletion_protection   = var.cluster_deletion_protection
  tags                  = local.common_tags
}
