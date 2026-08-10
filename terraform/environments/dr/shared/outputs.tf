output "contract_version" {
  description = "Semantic version of the regional shared-infrastructure contract."
  value       = local.contract_version
}

output "environment" {
  description = "Regional environment represented by this state."
  value       = local.environment
}

output "aws_region" {
  description = "AWS Region containing every resource in this state."
  value       = var.aws_region
}

output "vpc_id" {
  description = "DR shared VPC ID."
  value       = module.network.vpc_id
}

output "vpc_cidr_block" {
  description = "DR shared VPC IPv4 CIDR."
  value       = module.network.vpc_cidr_block
}

output "availability_zone_ids" {
  description = "Stable AZ IDs in subnet-list order."
  value       = module.network.availability_zone_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs ordered by availability_zone_ids."
  value       = module.network.public_subnet_ids
}

output "ec2_private_subnet_ids" {
  description = "EC2 private subnet IDs ordered by availability_zone_ids."
  value       = module.network.ec2_private_subnet_ids
}

output "eks_private_subnet_ids" {
  description = "EKS private subnet IDs ordered by availability_zone_ids."
  value       = module.network.eks_private_subnet_ids
}

output "database_subnet_ids" {
  description = "Database subnet IDs ordered by availability_zone_ids."
  value       = module.network.database_subnet_ids
}

output "private_route_table_ids" {
  description = "EC2, EKS, and database route-table IDs ordered by AZ ID."
  value       = module.network.private_route_table_ids
}

output "s3_gateway_endpoint_id" {
  description = "DR S3 gateway endpoint ID."
  value       = module.network.s3_gateway_endpoint_id
}

output "name_prefix" {
  description = "Approved DR shared naming prefix."
  value       = local.name_prefix
}

output "common_tags" {
  description = "Required base tags for downstream consumers."
  value       = local.common_tags
}

output "egress_mode" {
  description = "Selected private workload egress implementation."
  value       = module.network.egress_mode
}

output "nat_public_ip" {
  description = "Temporary recovery egress public IP, or null in pilot-light mode."
  value       = module.network.nat_public_ip
}
