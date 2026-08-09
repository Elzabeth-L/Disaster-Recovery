variable "name_prefix" {
  description = "Approved naming prefix for EC2 resources (e.g., vaultrix-dr-primary-ec2)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the EC2 security group and instance reside."
  type        = string
}

variable "subnet_id" {
  description = "Private subnet ID where the EC2 instance will be placed."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "Optional specific AMI ID. If null, latest Amazon Linux 2023 AMI is used."
  type        = string
  default     = null
}

variable "common_tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}

variable "user_data" {
  description = "Custom bootstrap script / user data for the EC2 instance. If null, default container deployment script is rendered."
  type        = string
  default     = null
}

variable "ingress_security_group_ids" {
  description = "List of security group IDs permitted to connect to this EC2 instance (e.g., ALB security group)."
  type        = list(string)
  default     = []
}

variable "ingress_cidr_blocks" {
  description = "List of CIDR blocks permitted to connect to this EC2 instance."
  type        = list(string)
  default     = []
}

variable "app_port" {
  description = "Application port for ingress traffic."
  type        = number
  default     = 8080
}

variable "db_secret_arn" {
  description = "Optional Secrets Manager secret ARN holding database credentials for tightly-scoped IAM access."
  type        = string
  default     = null
}

variable "app_image" {
  description = "GHCR Docker image reference to deploy on the EC2 instance."
  type        = string
  default     = "ghcr.io/elzabeth-l/vaultrix-ec2-app:latest"
}

variable "app_env" {
  description = "Application environment label (e.g. PRIMARY or DR)."
  type        = string
  default     = "PRIMARY"
}
