output "state_bucket_name" {
  description = "Name of the S3 bucket used by Terraform backends."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket used by Terraform backends."
  value       = aws_s3_bucket.terraform_state.arn
}

output "state_bucket_region" {
  description = "AWS Region of the Terraform state bucket."
  value       = var.aws_region
}

output "bootstrap_state_key" {
  description = "State key to use if bootstrap local state is migrated into the created bucket."
  value       = "bootstrap/terraform.tfstate"
}

