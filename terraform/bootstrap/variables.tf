variable "aws_region" {
  description = "AWS Region that stores the Terraform state bucket. Keep this stable after bootstrap."
  type        = string
  default     = "ap-south-1"

  validation {
    condition     = var.aws_region == "ap-south-1"
    error_message = "The approved bootstrap state Region is ap-south-1. Changing it requires an architecture decision."
  }
}

variable "expected_aws_account_id" {
  description = "Twelve-digit AWS account ID used as a safety boundary and in the globally unique bucket name."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_aws_account_id))
    error_message = "expected_aws_account_id must contain exactly 12 digits."
  }
}

variable "owner" {
  description = "Owner tag applied to bootstrap resources."
  type        = string

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner must not be empty."
  }
}

variable "cost_center" {
  description = "Cost allocation tag for the project or lab."
  type        = string
  default     = "disaster-recovery-lab"

  validation {
    condition     = length(trimspace(var.cost_center)) > 0
    error_message = "cost_center must not be empty."
  }
}

variable "noncurrent_version_retention_days" {
  description = "Days to retain noncurrent state object versions before lifecycle expiration."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_retention_days >= 30
    error_message = "Retain noncurrent state versions for at least 30 days."
  }
}

