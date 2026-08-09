output "contract_version" {
  description = "Contract version enforced by consumer root."
  value       = local.contract_version
}

output "consumed_vpc_id" {
  description = "Consumed DR shared VPC ID."
  value       = local.shared_vpc_id
}

output "consumed_vpc_cidr_block" {
  description = "Consumed DR shared VPC CIDR block."
  value       = local.shared_vpc_cidr_block
}

output "consumed_public_subnet_ids" {
  description = "Consumed DR public subnet IDs for ALB."
  value       = local.shared_public_subnet_ids
}

output "consumed_ec2_private_subnet_ids" {
  description = "Consumed DR EC2 private subnet IDs for application compute."
  value       = local.shared_ec2_private_subnets
}

output "consumed_database_subnet_ids" {
  description = "Consumed DR database subnet IDs for RDS Subnet Group."
  value       = local.shared_database_subnets
}

# DR EC2 Compute Instance Outputs
output "ec2_instance_id" {
  description = "ID of the DR EC2 instance."
  value       = module.ec2.instance_id
}

output "ec2_private_ip" {
  description = "Private IP address of the DR EC2 instance."
  value       = module.ec2.private_ip
}

output "ec2_security_group_id" {
  description = "Security group ID of the DR EC2 instance."
  value       = module.ec2.security_group_id
}

# DR ALB Outputs
output "alb_arn" {
  description = "ARN of the DR Application Load Balancer."
  value       = module.alb.alb_arn
}

output "alb_dns_name" {
  description = "Public DNS name of the DR Application Load Balancer."
  value       = module.alb.alb_dns_name
}

# DR RDS PostgreSQL Outputs
output "rds_instance_identifier" {
  description = "Identifier of the DR RDS PostgreSQL instance."
  value       = module.rds.db_instance_identifier
}

output "rds_endpoint" {
  description = "Connection endpoint of the DR RDS PostgreSQL instance."
  value       = module.rds.db_endpoint
}

output "rds_secret_arn" {
  description = "ARN of the DR Secrets Manager secret holding RDS credentials."
  value       = module.rds.secret_arn
}

# DR AWS Backup Outputs
output "backup_vault_id" {
  description = "ID/Name of the DR AWS Backup Vault."
  value       = module.aws_backup.backup_vault_id
}

output "backup_vault_arn" {
  description = "ARN of the DR AWS Backup Vault."
  value       = module.aws_backup.backup_vault_arn
}

# Route 53 Secondary DNS Outputs
output "dr_dns_record_name" {
  description = "Full FQDN of the DR EC2 application Route 53 failover record."
  value       = aws_route53_record.dr_ec2_alias.fqdn
}

output "dr_health_check_id" {
  description = "ID of the Route 53 health check monitoring the DR ALB."
  value       = aws_route53_health_check.dr_ec2.id
}

# CloudWatch / SNS Monitoring Outputs
output "sns_alerts_topic_arn" {
  description = "ARN of the SNS topic receiving CloudWatch alarm notifications in DR region."
  value       = module.cloudwatch_alarms.sns_topic_arn
}
