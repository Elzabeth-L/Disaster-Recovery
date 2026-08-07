locals {
  project_name = "vaultrix-dr"
  bucket_name  = "${local.project_name}-${var.expected_aws_account_id}-tfstate"

  common_tags = {
    Project            = local.project_name
    Environment        = "bootstrap"
    Application        = "shared"
    ManagedBy          = "terraform"
    Owner              = var.owner
    CostCenter         = var.cost_center
    Expiration         = "persistent"
    DataClassification = "confidential"
  }
}

