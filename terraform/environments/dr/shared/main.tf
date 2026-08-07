module "network" {
  source = "../../../modules/regional-network"

  name_prefix        = local.name_prefix
  environment        = local.environment
  vpc_cidr_block     = "10.20.0.0/16"
  subnet_cidr_blocks = local.subnet_cidr_blocks

  # Phase 3 is a pilot-light network. Recovery workflows may add temporary
  # egress later, but this shared state must not create permanent NAT capacity.
  egress_mode = "none"
}
