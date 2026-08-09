variable "name_prefix" {
  description = "Prefix used for EKS platform resources."
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version."
  type        = string
  default     = "1.35"
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the control plane and worker nodes."
  type        = list(string)
}

variable "github_apply_role_arn" {
  description = "GitHub OIDC apply role granted EKS administrator access."
  type        = string
}

variable "node_instance_types" {
  description = "ARM64 instance types for the managed node group; must satisfy account eligibility restrictions."
  type        = list(string)
  default     = ["t4g.small"]
}

variable "node_desired_size" {
  description = "Normal primary node count."
  type        = number
  default     = 2
}

variable "deletion_protection" {
  description = "Protect the EKS control plane from accidental deletion."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all supported resources."
  type        = map(string)
}
