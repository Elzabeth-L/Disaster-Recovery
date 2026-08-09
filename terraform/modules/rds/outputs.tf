output "db_instance_identifier" {
  description = "Identifier of the RDS PostgreSQL instance."
  value       = aws_db_instance.main.identifier
}

output "db_instance_arn" {
  description = "ARN of the RDS PostgreSQL instance."
  value       = aws_db_instance.main.arn
}

output "db_endpoint" {
  description = "Connection endpoint of the RDS PostgreSQL instance."
  value       = aws_db_instance.main.endpoint
}

output "db_address" {
  description = "Hostname address of the RDS PostgreSQL instance."
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "Port of the RDS PostgreSQL instance."
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Name of the initial database."
  value       = aws_db_instance.main.db_name
}

output "security_group_id" {
  description = "ID of the RDS security group."
  value       = aws_security_group.rds.id
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group."
  value       = aws_db_subnet_group.main.name
}

output "secret_arn" {
  description = "ARN of the AWS Secrets Manager secret storing DB credentials."
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "secret_name" {
  description = "Name of the AWS Secrets Manager secret storing DB credentials."
  value       = aws_secretsmanager_secret.db_credentials.name
}
