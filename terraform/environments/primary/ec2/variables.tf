variable "aws_region" {
  description = "AWS Region for primary EC2 workload state."
  type        = string
  default     = "ap-south-1"

  validation {
    condition     = var.aws_region == "ap-south-1"
    error_message = "The primary EC2 state must remain in ap-south-1."
  }
}

variable "state_bucket" {
  description = "S3 bucket name holding shared remote state."
  type        = string
  default     = ""
}

variable "state_region" {
  description = "AWS Region of the S3 backend bucket."
  type        = string
  default     = "ap-south-1"
}

variable "app_image" {
  description = "Immutable GHCR Docker image reference to deploy on the primary EC2 instance."
  type        = string
  default     = "ghcr.io/elzabeth-l/disaster-recovery/vaultrix-ec2-app:latest"
}

variable "backup_schedule" {
  description = "Cron schedule expression for AWS Backup."
  type        = string
  default     = "cron(0 2 * * ? *)"
}

variable "backup_retention_days" {
  description = "Retention period in days for primary EC2 & RDS backups."
  type        = number
  default     = 30
}

variable "copy_action_destination_vault_arn" {
  description = "ARN of the DR region backup vault to copy Primary backups into for cross-region DR data continuity. Set to the vaultrix-dr-dr-ec2-backup-vault ARN in ap-southeast-1."
  type        = string
  default     = null
}

variable "alarm_email" {
  description = "Email address to receive CloudWatch alarm notifications via SNS."
  type        = string
  default     = ""
}
