locals {
  project          = "vaultrix-dr"
  environment      = "primary"
  application      = "shared"
  contract_version = "1.0.0"
  name_prefix      = "${local.project}-${local.environment}-${local.application}"

  common_tags = {
    Project            = local.project
    Environment        = local.environment
    Application        = local.application
    ManagedBy          = "terraform"
    Owner              = var.owner
    CostCenter         = var.cost_center
    Expiration         = "persistent"
    DataClassification = "internal"
  }

  subnet_cidr_blocks = {
    public      = ["10.10.1.0/24", "10.10.2.0/24"]
    ec2_private = ["10.10.11.0/24", "10.10.12.0/24"]
    eks_private = ["10.10.21.0/24", "10.10.22.0/24"]
    database    = ["10.10.31.0/24", "10.10.32.0/24"]
  }
}
