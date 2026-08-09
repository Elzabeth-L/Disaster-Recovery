variable "aws_region" {
  description = "AWS Region for DR EC2 workload state."
  type        = string
  default     = "ap-southeast-1"

  validation {
    condition     = var.aws_region == "ap-southeast-1"
    error_message = "The DR EC2 state must remain in ap-southeast-1."
  }
}

variable "expected_aws_account_id" {
  description = "Twelve-digit AWS account ID used as a provider safety boundary."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_aws_account_id))
    error_message = "expected_aws_account_id must be a 12-digit AWS account ID."
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
  description = "Immutable GHCR Docker image reference to deploy on the DR EC2 instance."
  type        = string
  default     = "ghcr.io/elzabeth-l/vaultrix-ec2-app:latest"
}

variable "backup_schedule" {
  description = "Cron schedule expression for DR AWS Backup."
  type        = string
  default     = "cron(0 2 * * ? *)"
}

variable "backup_retention_days" {
  description = "Retention period in days for DR EC2 & RDS backups."
  type        = number
  default     = 30
}

variable "alarm_email" {
  description = "Email address to receive CloudWatch alarm notifications via SNS."
  type        = string
  default     = ""
}
