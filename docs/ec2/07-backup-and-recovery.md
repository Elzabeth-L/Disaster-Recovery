# 07. AWS Backup & Data Protection — Comprehensive Notes

## 1. Overview

Data protection and multi-region replication are managed using AWS Backup (`terraform/modules/aws-backup`). The backup plan automatically takes daily snapshots of the Primary EC2 instance and RDS PostgreSQL database in Mumbai (`ap-south-1`) and replicates recovery points to a destination backup vault in Singapore (`ap-southeast-1`).

---

## 2. AWS Backup Module Architecture (`terraform/modules/aws-backup/main.tf`)

```hcl
# AWS Backup IAM Service Role
resource "aws_iam_role" "backup" {
  name        = "${var.name_prefix}-backup-role"
  description = "IAM role used by AWS Backup to perform backup and restore operations"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "backup.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Attach AWS Managed Backup & Restore Policies
resource "aws_iam_role_policy_attachment" "backup_service_role" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore_service_role" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# AWS Backup Vault
resource "aws_backup_vault" "main" {
  name = "${var.name_prefix}-backup-vault"
}

# AWS Backup Plan with Daily Schedule & Cross-Region Copy Rule
resource "aws_backup_plan" "main" {
  name = "${var.name_prefix}-backup-plan"

  rule {
    rule_name         = "${var.name_prefix}-daily-rule"
    target_vault_name = aws_backup_vault.main.name
    schedule          = var.backup_schedule # cron(0 2 * * ? *)
    start_window      = var.backup_start_window_minutes # 60 min
    completion_window = var.backup_completion_window_minutes # 180 min

    lifecycle {
      delete_after = var.backup_retention_days # 30 days
    }

    # Cross-region copy to DR vault when destination ARN is provided
    dynamic "copy_action" {
      for_each = var.copy_action_destination_vault_arn != null ? [1] : []
      content {
        destination_vault_arn = var.copy_action_destination_vault_arn
        lifecycle {
          delete_after = var.backup_retention_days
        }
      }
    }
  }
}

# AWS Backup Selection targeting EC2 and RDS ARNs
resource "aws_backup_selection" "main" {
  name         = "${var.name_prefix}-backup-selection"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.main.id
  resources    = var.selection_resources
}
```

---

## 3. Replication Lifecycle & Backup Schedule

1. **Trigger Time**: `cron(0 2 * * ? *)` (Every day at 02:00 UTC).
2. **Snapshot Creation**: AWS Backup triggers parallel snapshot creation for Primary EC2 Instance ARN and Primary RDS Instance ARN.
3. **Cross-Region Replication**: Once the primary snapshot is complete, AWS Backup evaluates the `copy_action` block and securely copies the recovery point to the destination vault `vaultrix-dr-dr-ec2-backup-vault` in `ap-southeast-1`.
4. **Retention**: Snapshots are retained for 30 days before automatic deletion.
