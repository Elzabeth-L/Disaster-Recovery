variable "name_prefix" {
  description = "Approved naming prefix for ALB resources (e.g. vaultrix-dr-primary-ec2)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB security group and target group reside."
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for internet-facing ALB placement."
  type        = list(string)
}

variable "target_instance_id" {
  description = "EC2 instance ID to register with the target group."
  type        = string
}

variable "app_port" {
  description = "Application port on the EC2 target instance."
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "HTTP path for ALB health check."
  type        = string
  default     = "/health"
}

variable "common_tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}
