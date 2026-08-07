variable "aws_region" {
  description = "Provider and state-bucket Region for global/account resources."
  type        = string
  default     = "ap-south-1"

  validation {
    condition     = var.aws_region == "ap-south-1"
    error_message = "The global shared provider must remain in ap-south-1."
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

variable "owner" {
  description = "Owner tag applied to global shared resources."
  type        = string

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner must not be empty."
  }
}

variable "cost_center" {
  description = "CostCenter tag applied to global shared resources."
  type        = string
  default     = "disaster-recovery-lab"
}

variable "github_repository_owner" {
  description = "Exact GitHub repository owner encoded in OIDC subject claims."
  type        = string
  default     = "Elzabeth-L"

  validation {
    condition     = var.github_repository_owner == "Elzabeth-L"
    error_message = "OIDC trust is intentionally restricted to Elzabeth-L."
  }
}

variable "github_repository_name" {
  description = "Exact GitHub repository name encoded in OIDC subject claims."
  type        = string
  default     = "Disaster-Recovery"

  validation {
    condition     = var.github_repository_name == "Disaster-Recovery"
    error_message = "OIDC trust is intentionally restricted to Disaster-Recovery."
  }
}
