variable "aws_region" {
  description = "AWS Region for the DR shared network."
  type        = string
  default     = "ap-southeast-1"

  validation {
    condition     = var.aws_region == "ap-southeast-1"
    error_message = "The DR shared network must remain in ap-southeast-1."
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
  description = "Owner tag applied to Phase 3 resources."
  type        = string

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner must not be empty."
  }
}

variable "cost_center" {
  description = "CostCenter tag applied to Phase 3 resources."
  type        = string
  default     = "disaster-recovery-lab"
}

variable "recovery_egress_enabled" {
  description = "Enable the temporary cost-first NAT instance during a declared DR drill."
  type        = bool
  default     = false
}

variable "cost_acknowledgement" {
  description = "Required acknowledgement when temporary DR egress is enabled."
  type        = string
  default     = ""
}

check "recovery_egress_cost_gate" {
  assert {
    condition     = !var.recovery_egress_enabled || var.cost_acknowledgement == "APPROVE_DR_DRILL_COSTS"
    error_message = "Set cost_acknowledgement to APPROVE_DR_DRILL_COSTS when enabling temporary DR egress."
  }
}
