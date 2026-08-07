module "network" {
  source = "../../../modules/regional-network"

  name_prefix        = local.name_prefix
  environment        = local.environment
  vpc_cidr_block     = "10.10.0.0/16"
  subnet_cidr_blocks = local.subnet_cidr_blocks
  egress_mode        = var.egress_mode
  nat_instance_type  = var.nat_instance_type
}
