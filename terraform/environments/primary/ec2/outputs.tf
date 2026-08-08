output "contract_version" {
  description = "Contract version enforced by consumer root."
  value       = local.contract_version
}

output "consumed_vpc_id" {
  description = "Consumed primary shared VPC ID."
  value       = local.shared_vpc_id
}

output "consumed_vpc_cidr_block" {
  description = "Consumed primary shared VPC CIDR block."
  value       = local.shared_vpc_cidr_block
}

output "consumed_public_subnet_ids" {
  description = "Consumed primary public subnet IDs for future ALB."
  value       = local.shared_public_subnet_ids
}

output "consumed_ec2_private_subnet_ids" {
  description = "Consumed primary EC2 private subnet IDs for application compute."
  value       = local.shared_ec2_private_subnets
}

output "consumed_database_subnet_ids" {
  description = "Consumed primary database subnet IDs for RDS Subnet Group."
  value       = local.shared_database_subnets
}

output "consumed_route53_zone_id" {
  description = "Consumed global Route 53 zone ID for project DNS."
  value       = local.global_route53_zone_id
}

output "consumed_route53_zone_name" {
  description = "Consumed global Route 53 zone name."
  value       = local.global_route53_zone_name
}

output "consumed_github_ec2_role_arn" {
  description = "Consumed EC2 GitHub Actions apply role ARN."
  value       = local.global_github_ec2_role
}

# Primary EC2 Compute Instance Outputs
output "ec2_instance_id" {
  description = "ID of the primary EC2 instance."
  value       = module.ec2.instance_id
}

output "ec2_private_ip" {
  description = "Private IP address of the primary EC2 instance."
  value       = module.ec2.private_ip
}

output "ec2_security_group_id" {
  description = "Security group ID of the primary EC2 instance."
  value       = module.ec2.security_group_id
}

output "ec2_iam_role_arn" {
  description = "IAM role ARN attached to the primary EC2 instance for SSM access."
  value       = module.ec2.iam_role_arn
}
