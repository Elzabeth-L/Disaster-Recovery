module "network" {
  source = "../../../modules/regional-network"

  name_prefix        = local.name_prefix
  environment        = local.environment
  vpc_cidr_block     = "10.20.0.0/16"
  subnet_cidr_blocks = local.subnet_cidr_blocks

  # General egress remains absent in pilot-light mode. A protected recovery
  # workflow enables the cost-first NAT instance only for a declared drill.
  egress_mode = var.recovery_egress_enabled ? "nat_instance" : "none"
}
