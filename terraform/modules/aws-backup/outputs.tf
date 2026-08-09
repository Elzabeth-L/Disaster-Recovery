output "backup_vault_id" {
  description = "ID/Name of the AWS Backup Vault."
  value       = aws_backup_vault.main.id
}

output "backup_vault_arn" {
  description = "ARN of the AWS Backup Vault."
  value       = aws_backup_vault.main.arn
}

output "backup_plan_id" {
  description = "ID of the AWS Backup Plan."
  value       = aws_backup_plan.main.id
}

output "backup_plan_arn" {
  description = "ARN of the AWS Backup Plan."
  value       = aws_backup_plan.main.arn
}

output "backup_role_arn" {
  description = "ARN of the IAM role used by AWS Backup."
  value       = aws_iam_role.backup.arn
}
