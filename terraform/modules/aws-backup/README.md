# Reusable AWS Backup Module

This module provisions an AWS Backup foundation for protecting EC2 compute instances and RDS PostgreSQL databases:
- **AWS Backup Vault** (`aws_backup_vault.main`): Secure vault for backup recovery points.
- **AWS Backup Plan** (`aws_backup_plan.main`): Daily backup schedule (`var.backup_schedule`), retention period (`var.backup_retention_days`), start and completion windows.
- **AWS Backup Selection** (`aws_backup_selection.main`): Target resource selection matching explicit ARNs (`module.ec2.instance_arn`, `module.rds.db_instance_arn`) and/or selection tags.
- **IAM Role** (`aws_iam_role.backup`): Dedicated service role attached with `AWSBackupServiceRolePolicyForBackup` and `AWSBackupServiceRolePolicyForRestores`.
