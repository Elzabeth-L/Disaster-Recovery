output "instance_id" {
  description = "ID of the created EC2 instance."
  value       = aws_instance.app.id
}

output "instance_arn" {
  description = "ARN of the created EC2 instance."
  value       = aws_instance.app.arn
}

output "private_ip" {
  description = "Private IP address of the EC2 instance."
  value       = aws_instance.app.private_ip
}

output "security_group_id" {
  description = "ID of the EC2 security group."
  value       = aws_security_group.app.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role attached to the EC2 instance."
  value       = aws_iam_role.ssm.arn
}

output "iam_role_name" {
  description = "Name of the IAM role attached to the EC2 instance."
  value       = aws_iam_role.ssm.name
}

output "instance_profile_arn" {
  description = "ARN of the EC2 instance profile."
  value       = aws_iam_instance_profile.app.arn
}
