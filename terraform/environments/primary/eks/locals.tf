locals {
  contract_version = "1.0.0"
  name_prefix      = "vaultrix-dr-primary-eks"

  common_tags = merge(data.terraform_remote_state.primary_shared.outputs.common_tags, {
    Application = "eks"
    Owner       = "Elzabeth-L"
    Expiration  = "persistent-primary"
  })
}
