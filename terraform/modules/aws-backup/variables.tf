variable "name_prefix" {
  description = "Approved naming prefix for backup resources (e.g. vaultrix-dr-primary-ec2)."
  type        = string
}

variable "backup_schedule" {
  description = "Cron schedule expression for AWS Backup (e.g. cron(0 2 * * ? *))."
  type        = string
  default     = "cron(0 2 * * ? *)"
}

variable "backup_retention_days" {
  description = "Retention period in days for backups."
  type        = number
  default     = 30
}

variable "backup_start_window_minutes" {
  description = "Start window in minutes after schedule trigger."
  type        = number
  default     = 60
}

variable "backup_completion_window_minutes" {
  description = "Completion window in minutes after backup starts."
  type        = number
  default     = 180
}

variable "selection_resources" {
  description = "List of explicit resource ARNs to protect with AWS Backup (e.g. RDS ARN, EC2 ARN)."
  type        = list(string)
  default     = []
}

variable "selection_tags" {
  description = "List of tag condition maps for tag-based resource selection."
  type = list(object({
    type  = string
    key   = string
    value = string
  }))
  default = []
}

variable "copy_action_destination_vault_arn" {
  description = "Optional ARN of a destination backup vault for cross-region copy. When set, every backup is copied to this vault (e.g., DR vault in ap-southeast-1)."
  type        = string
  default     = null
}

variable "common_tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}
