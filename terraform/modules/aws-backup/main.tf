# AWS Backup IAM Service Role
resource "aws_iam_role" "backup" {
  name        = "${var.name_prefix}-backup-role"
  description = "IAM role used by AWS Backup to perform backup and restore operations"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-backup-role"
    }
  )
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

# Dedicated AWS Backup Vault for EC2/RDS Application Ownership Scope
resource "aws_backup_vault" "main" {
  name = "${var.name_prefix}-backup-vault"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-backup-vault"
    }
  )
}

# AWS Backup Plan with Daily Schedule & Retention
resource "aws_backup_plan" "main" {
  name = "${var.name_prefix}-backup-plan"

  rule {
    rule_name         = "${var.name_prefix}-daily-rule"
    target_vault_name = aws_backup_vault.main.name
    schedule          = var.backup_schedule
    start_window      = var.backup_start_window_minutes
    completion_window = var.backup_completion_window_minutes

    lifecycle {
      delete_after = var.backup_retention_days
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-backup-plan"
    }
  )
}

# AWS Backup Selection targeting specified resources and/or tags
resource "aws_backup_selection" "main" {
  name         = "${var.name_prefix}-backup-selection"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.main.id

  resources = var.selection_resources

  dynamic "selection_tag" {
    for_each = var.selection_tags
    content {
      type  = selection_tag.value.type
      key   = selection_tag.value.key
      value = selection_tag.value.value
    }
  }
}
