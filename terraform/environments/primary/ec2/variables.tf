variable "aws_region" {
  description = "AWS Region for primary EC2 workload state."
  type        = string
  default     = "ap-south-1"

  validation {
    condition     = var.aws_region == "ap-south-1"
    error_message = "The primary EC2 state must remain in ap-south-1."
  }
}

variable "state_bucket" {
  description = "S3 bucket name holding shared remote state."
  type        = string
  default     = ""
}

variable "state_region" {
  description = "AWS Region of the S3 backend bucket."
  type        = string
  default     = "ap-south-1"
}

variable "app_image" {
  description = "Immutable GHCR Docker image reference to deploy on the primary EC2 instance."
  type        = string
  default     = "ghcr.io/elzabeth-l/disaster-recovery/vaultrix-ec2-app:latest"
}
