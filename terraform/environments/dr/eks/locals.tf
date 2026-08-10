locals {
  contract_version = "1.0.0"
  name_prefix      = "vaultrix-dr-dr-eks"

  common_tags = merge(data.terraform_remote_state.dr_shared.outputs.common_tags, {
    Application = "eks"
    Owner       = "Elzabeth-L"
    Expiration  = "temporary-dr-drill"
  })
}
