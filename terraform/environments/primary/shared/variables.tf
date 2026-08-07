variable "aws_region" {
  description = "AWS Region for the primary shared network."
  type        = string
  default     = "ap-south-1"

  validation {
    condition     = var.aws_region == "ap-south-1"
    error_message = "The primary shared network must remain in ap-south-1."
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
  description = "Owner tag applied to Phase 2 resources."
  type        = string

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner must not be empty."
  }
}

variable "cost_center" {
  description = "CostCenter tag applied to Phase 2 resources."
  type        = string
  default     = "disaster-recovery-lab"
}

variable "egress_mode" {
  description = "Cost-first nat_instance, managed nat_gateway fallback, or none."
  type        = string
  default     = "nat_instance"

  validation {
    condition     = contains(["nat_instance", "nat_gateway", "none"], var.egress_mode)
    error_message = "egress_mode must be nat_instance, nat_gateway, or none."
  }
}

variable "nat_instance_type" {
  description = "ARM64 NAT instance type."
  type        = string
  default     = "t4g.nano"
}
