variable "name_prefix" {
  description = "Approved naming prefix for alarm resources (e.g., vaultrix-dr-primary-ec2)."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer (e.g., app/vaultrix-dr-primary-ec2-alb/abc123). Used to identify ALB metrics in CloudWatch."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the ALB Target Group (e.g., targetgroup/vaultrix-dr-primary-ec2-tg/abc123). Required for UnhealthyHostCount metric."
  type        = string
}

variable "ec2_instance_id" {
  description = "ID of the primary EC2 instance to monitor (e.g., i-0abc123456789)."
  type        = string
}

variable "rds_identifier" {
  description = "Identifier of the RDS instance to monitor (e.g., vaultrix-dr-primary-ec2-rds)."
  type        = string
}

variable "alarm_email" {
  description = "Email address to receive CloudWatch alarm notifications. Leave empty to skip email subscription."
  type        = string
  default     = ""
}

variable "rds_free_storage_threshold_bytes" {
  description = "Alarm threshold in bytes for RDS free storage space. Default is 2 GiB."
  type        = number
  default     = 2147483648
}

variable "common_tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}
