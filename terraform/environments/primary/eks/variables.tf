variable "aws_region" {
  type        = string
  description = "Primary AWS Region."
  default     = "ap-south-1"
  validation {
    condition     = var.aws_region == "ap-south-1"
    error_message = "Primary EKS must remain in ap-south-1."
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
  description = "Explicit cost gate. False creates no EKS resources."
  default     = false
}

variable "cost_acknowledgement" {
  type        = string
  description = "Required acknowledgement when planning or applying the cost-bearing platform."
  default     = ""
}

variable "kubernetes_version" {
  type        = string
  description = "EKS Kubernetes minor version."
  default     = "1.35"
}

variable "cluster_deletion_protection" {
  type        = bool
  description = "Keep true normally; disable in a separately reviewed pre-destroy apply."
  default     = true
}
