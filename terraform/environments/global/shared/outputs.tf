output "contract_version" {
  description = "Semantic version of the global shared-infrastructure contract."
  value       = local.contract_version
}

output "route53_zone_id" {
  description = "Route 53 public hosted-zone ID for dr.vaultrix.in."
  value       = aws_route53_zone.project.zone_id
}

output "route53_zone_name" {
  description = "Delegated project DNS zone name."
  value       = aws_route53_zone.project.name
}

output "route53_name_servers" {
  description = "Authoritative name servers to delegate manually at GoDaddy after approval."
  value       = aws_route53_zone.project.name_servers
}

output "github_oidc_provider_arn" {
  description = "Existing account-level GitHub Actions OIDC provider referenced read-only by this state."
  value       = data.aws_iam_openid_connect_provider.github.arn
}

output "github_shared_role_arn" {
  description = "Protected shared apply-role ARN retained by contract v1."
  value       = aws_iam_role.github["shared_apply"].arn
}

output "github_eks_role_arn" {
  description = "Protected EKS apply-role ARN retained by contract v1."
  value       = aws_iam_role.github["eks_apply"].arn
}

output "github_ec2_role_arn" {
  description = "Protected EC2 apply-role ARN retained by contract v1."
  value       = aws_iam_role.github["ec2_apply"].arn
}

output "eks_operator_user_arn" {
  description = "Dedicated human-operated IAM user authorized in both project EKS clusters."
  value       = aws_iam_user.eks_operator.arn
}

output "ec2_operator_user_arn" {
  description = "Dedicated human-operated IAM user authorized for project EC2 Session Manager access."
  value       = aws_iam_user.ec2_operator.arn
}

output "github_plan_role_arns" {
  description = "Read-oriented plan-role ARNs keyed by ownership scope."
  value = {
    shared = aws_iam_role.github["shared_plan"].arn
    eks    = aws_iam_role.github["eks_plan"].arn
    ec2    = aws_iam_role.github["ec2_plan"].arn
  }
}

output "github_apply_environment_names" {
  description = "Exact GitHub Environment names encoded in apply-role trust policies."
  value       = ["shared-apply", "eks-apply", "ec2-apply"]
}

output "primary_region" {
  description = "Primary AWS Region."
  value       = "ap-south-1"
}

output "dr_region" {
  description = "Disaster-recovery AWS Region."
  value       = "ap-southeast-1"
}
