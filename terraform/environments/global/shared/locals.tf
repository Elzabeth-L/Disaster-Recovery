locals {
  project          = "vaultrix-dr"
  environment      = "global"
  application      = "shared"
  contract_version = "1.0.0"
  name_prefix      = "${local.project}-${local.environment}-${local.application}"
  hosted_zone_name = "dr.vaultrix.in"
  repository       = "${var.github_repository_owner}/${var.github_repository_name}"
  state_bucket_arn = "arn:aws:s3:::vaultrix-dr-${var.expected_aws_account_id}-tfstate"

  common_tags = {
    Project            = local.project
    Environment        = local.environment
    Application        = local.application
    ManagedBy          = "terraform"
    Owner              = var.owner
    CostCenter         = var.cost_center
    Expiration         = "persistent"
    DataClassification = "internal"
  }

  shared_state_keys = [
    "global/shared/terraform.tfstate",
    "primary/shared/terraform.tfstate",
    "dr/shared/terraform.tfstate",
  ]
  eks_state_keys = [
    "primary/eks/terraform.tfstate",
    "dr/eks/terraform.tfstate",
  ]
  ec2_state_keys = [
    "primary/ec2/terraform.tfstate",
    "dr/ec2/terraform.tfstate",
  ]

  role_definitions = {
    shared_plan = {
      role_name           = "vaultrix-dr-github-shared-plan"
      subjects            = ["repo:${local.repository}:pull_request", "repo:${local.repository}:ref:refs/heads/main"]
      readable_state_keys = local.shared_state_keys
      writable_state_keys = []
      lockable_state_keys = local.shared_state_keys
      denied_prefixes     = ["primary/eks/*", "dr/eks/*", "primary/ec2/*", "dr/ec2/*"]
      dns_names           = []
    }
    shared_apply = {
      role_name           = "vaultrix-dr-github-shared-apply"
      subjects            = ["repo:${local.repository}:environment:shared-apply"]
      readable_state_keys = local.shared_state_keys
      writable_state_keys = local.shared_state_keys
      lockable_state_keys = local.shared_state_keys
      denied_prefixes     = ["primary/eks/*", "dr/eks/*", "primary/ec2/*", "dr/ec2/*"]
      dns_names           = ["*"]
    }
    eks_plan = {
      role_name           = "vaultrix-dr-github-eks-plan"
      subjects            = ["repo:${local.repository}:pull_request", "repo:${local.repository}:ref:refs/heads/main"]
      readable_state_keys = concat(local.shared_state_keys, local.eks_state_keys)
      writable_state_keys = []
      lockable_state_keys = local.eks_state_keys
      denied_prefixes     = ["bootstrap/*", "global/shared/*", "primary/shared/*", "dr/shared/*", "primary/ec2/*", "dr/ec2/*"]
      dns_names           = []
    }
    eks_apply = {
      role_name           = "vaultrix-dr-github-eks-apply"
      subjects            = ["repo:${local.repository}:environment:eks-apply"]
      readable_state_keys = concat(local.shared_state_keys, local.eks_state_keys)
      writable_state_keys = local.eks_state_keys
      lockable_state_keys = local.eks_state_keys
      denied_prefixes     = ["bootstrap/*", "global/shared/*", "primary/shared/*", "dr/shared/*", "primary/ec2/*", "dr/ec2/*"]
      dns_names           = ["eks.dr.vaultrix.in", "eks-primary.dr.vaultrix.in", "eks-dr.dr.vaultrix.in"]
    }
    ec2_plan = {
      role_name           = "vaultrix-dr-github-ec2-plan"
      subjects            = ["repo:${local.repository}:pull_request", "repo:${local.repository}:ref:refs/heads/main"]
      readable_state_keys = concat(local.shared_state_keys, local.ec2_state_keys)
      writable_state_keys = []
      lockable_state_keys = local.ec2_state_keys
      denied_prefixes     = ["bootstrap/*", "global/shared/*", "primary/shared/*", "dr/shared/*", "primary/eks/*", "dr/eks/*"]
      dns_names           = []
    }
    ec2_apply = {
      role_name           = "vaultrix-dr-github-ec2-apply"
      subjects            = ["repo:${local.repository}:environment:ec2-apply"]
      readable_state_keys = concat(local.shared_state_keys, local.ec2_state_keys)
      writable_state_keys = local.ec2_state_keys
      lockable_state_keys = local.ec2_state_keys
      denied_prefixes     = ["bootstrap/*", "global/shared/*", "primary/shared/*", "dr/shared/*", "primary/eks/*", "dr/eks/*"]
      dns_names           = ["ec2.dr.vaultrix.in", "ec2-primary.dr.vaultrix.in", "ec2-dr.dr.vaultrix.in"]
    }
  }

  read_actions = [
    "autoscaling:Describe*",
    "backup:Describe*",
    "backup:Get*",
    "backup:List*",
    "cloudwatch:Describe*",
    "cloudwatch:Get*",
    "cloudwatch:List*",
    "ec2:Describe*",
    "ecr:Describe*",
    "ecr:List*",
    "eks:Describe*",
    "eks:List*",
    "elasticloadbalancing:Describe*",
    "iam:Get*",
    "iam:List*",
    "kms:Describe*",
    "kms:Get*",
    "kms:List*",
    "logs:Describe*",
    "logs:Get*",
    "logs:List*",
    "rds:Describe*",
    "rds:ListTagsForResource",
    "route53:Get*",
    "route53:List*",
    "secretsmanager:DescribeSecret",
    "secretsmanager:ListSecrets",
    "servicequotas:Get*",
    "servicequotas:List*",
    "sns:Get*",
    "sns:List*",
    "sts:GetCallerIdentity",
    "tag:GetResources",
  ]
}
