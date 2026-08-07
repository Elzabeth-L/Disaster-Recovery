variable "name_prefix" {
  description = "Stable prefix used for regional shared-network resource names."
  type        = string
}

variable "environment" {
  description = "Environment name used in tags and outputs."
  type        = string
}

variable "vpc_cidr_block" {
  description = "IPv4 CIDR assigned to the regional VPC."
  type        = string
}

variable "subnet_cidr_blocks" {
  description = "Two ordered CIDRs for each subnet tier. Order follows the selected AZ IDs."
  type = object({
    public      = list(string)
    ec2_private = list(string)
    eks_private = list(string)
    database    = list(string)
  })

  validation {
    condition = alltrue([
      for cidrs in values(var.subnet_cidr_blocks) : length(cidrs) == 2
    ]) && length(distinct(flatten(values(var.subnet_cidr_blocks)))) == 8
    error_message = "Each subnet tier must contain two CIDRs, and all eight CIDRs must be unique."
  }
}

variable "egress_mode" {
  description = "Private workload egress: cost-first nat_instance, managed nat_gateway fallback, or none."
  type        = string
  default     = "nat_instance"

  validation {
    condition     = contains(["nat_instance", "nat_gateway", "none"], var.egress_mode)
    error_message = "egress_mode must be nat_instance, nat_gateway, or none."
  }
}

variable "nat_instance_type" {
  description = "ARM64 instance type for the cost-first NAT instance."
  type        = string
  default     = "t4g.nano"
}

variable "nat_instance_ami_ssm_parameter" {
  description = "Public SSM parameter resolving the current Amazon Linux 2023 ARM64 AMI."
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}
