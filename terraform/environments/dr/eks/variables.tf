variable "aws_region" {
  type        = string
  description = "DR AWS Region."
  default     = "ap-southeast-1"
  validation {
    condition     = var.aws_region == "ap-southeast-1"
    error_message = "DR EKS must remain in ap-southeast-1."
  }
}

variable "expected_aws_account_id" {
  type        = string
  description = "Twelve-digit AWS account safety boundary."
  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_aws_account_id))
    error_message = "expected_aws_account_id must contain 12 digits."
  }
}

variable "state_bucket" {
  type        = string
  description = "Shared Terraform state bucket."
  default     = ""
}

variable "state_region" {
  type        = string
  description = "Terraform state bucket Region."
  default     = "ap-south-1"
}

variable "deployment_enabled" {
  type        = bool
  description = "Explicit cost gate. False removes the temporary DR EKS platform."
  default     = false
}

variable "cost_acknowledgement" {
  type        = string
  description = "Required acknowledgement when enabling the temporary DR EKS platform."
  default     = ""
}

variable "kubernetes_version" {
  type        = string
  description = "EKS Kubernetes minor version."
  default     = "1.35"
}

check "cost_gate" {
  assert {
    condition     = !var.deployment_enabled || var.cost_acknowledgement == "APPROVE_DR_DRILL_COSTS"
    error_message = "Set cost_acknowledgement to APPROVE_DR_DRILL_COSTS when enabling DR EKS."
  }
}
