locals {
  project          = "vaultrix-dr"
  environment      = "dr"
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
    public      = ["10.20.1.0/24", "10.20.2.0/24"]
    ec2_private = ["10.20.11.0/24", "10.20.12.0/24"]
    eks_private = ["10.20.21.0/24", "10.20.22.0/24"]
    database    = ["10.20.31.0/24", "10.20.32.0/24"]
  }
}
