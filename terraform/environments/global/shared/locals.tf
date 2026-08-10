locals {
  project          = "vaultrix-dr"
  environment      = "global"
  application      = "shared"
  contract_version = "1.0.0"
  name_prefix      = "${local.project}-${local.environment}-${local.application}"
  hosted_zone_name = "dr.vaultrix.in"
  repository       = "${var.github_repository_owner}/${var.github_repository_name}"
  repository_subject = format(
    "%s@%d/%s@%d",
    var.github_repository_owner,
    var.github_repository_owner_id,
    var.github_repository_name,
    var.github_repository_id,
  )
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
      subjects            = ["repo:${local.repository_subject}:pull_request", "repo:${local.repository_subject}:ref:refs/heads/main"]
      readable_state_keys = local.shared_state_keys
      writable_state_keys = []
      lockable_state_keys = local.shared_state_keys
      denied_prefixes     = ["primary/eks/*", "dr/eks/*", "primary/ec2/*", "dr/ec2/*"]
      dns_names           = []
    }
    shared_apply = {
      role_name           = "vaultrix-dr-github-shared-apply"
      subjects            = ["repo:${local.repository_subject}:environment:shared-apply"]
      readable_state_keys = local.shared_state_keys
      writable_state_keys = local.shared_state_keys
      lockable_state_keys = local.shared_state_keys
      denied_prefixes     = ["primary/eks/*", "dr/eks/*", "primary/ec2/*", "dr/ec2/*"]
      dns_names           = ["*"]
    }
    eks_plan = {
      role_name           = "vaultrix-dr-github-eks-plan"
      subjects            = ["repo:${local.repository_subject}:pull_request", "repo:${local.repository_subject}:ref:refs/heads/main"]
      readable_state_keys = concat(local.shared_state_keys, local.eks_state_keys)
      writable_state_keys = []
      lockable_state_keys = local.eks_state_keys
      denied_prefixes     = ["bootstrap/*", "global/shared/*", "primary/shared/*", "dr/shared/*", "primary/ec2/*", "dr/ec2/*"]
      dns_names           = []
    }
    eks_apply = {
      role_name           = "vaultrix-dr-github-eks-apply"
      subjects            = ["repo:${local.repository_subject}:environment:eks-apply"]
      readable_state_keys = concat(local.shared_state_keys, local.eks_state_keys)
      writable_state_keys = local.eks_state_keys
      lockable_state_keys = local.eks_state_keys
      denied_prefixes     = ["bootstrap/*", "global/shared/*", "primary/shared/*", "dr/shared/*", "primary/ec2/*", "dr/ec2/*"]
      dns_names           = ["eks.dr.vaultrix.in", "eks-primary.dr.vaultrix.in", "eks-dr.dr.vaultrix.in"]
    }
    ec2_plan = {
      role_name           = "vaultrix-dr-github-ec2-plan"
      subjects            = ["repo:${local.repository_subject}:pull_request", "repo:${local.repository_subject}:ref:refs/heads/main"]
      readable_state_keys = concat(local.shared_state_keys, local.ec2_state_keys)
      writable_state_keys = []
      lockable_state_keys = local.ec2_state_keys
      denied_prefixes     = ["bootstrap/*", "global/shared/*", "primary/shared/*", "dr/shared/*", "primary/eks/*", "dr/eks/*"]
      dns_names           = []
    }
    ec2_apply = {
      role_name           = "vaultrix-dr-github-ec2-apply"
      subjects            = ["repo:${local.repository_subject}:environment:ec2-apply"]
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
    "ecr:GetLifecyclePolicy",
    "ecr:GetLifecyclePolicyPreview",
    "ecr:GetRepositoryPolicy",
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
    "secretsmanager:GetResourcePolicy",
    "secretsmanager:ListSecretVersionIds",
    "secretsmanager:ListSecrets",
    "servicequotas:Get*",
    "servicequotas:List*",
    "sns:Get*",
    "sns:List*",
    "sts:GetCallerIdentity",
    "tag:GetResources",
  ]

  eks_apply_actions = [
    "autoscaling:CreateOrUpdateTags",
    "autoscaling:DeleteTags",
    "ec2:AuthorizeSecurityGroupEgress",
    "ec2:AuthorizeSecurityGroupIngress",
    "ec2:CreateSecurityGroup",
    "ec2:CreateTags",
    "ec2:DeleteSecurityGroup",
    "ec2:RevokeSecurityGroupEgress",
    "ec2:RevokeSecurityGroupIngress",
    "ecr:BatchCheckLayerAvailability",
    "ecr:BatchDeleteImage",
    "ecr:CompleteLayerUpload",
    "ecr:CreateRepository",
    "ecr:DeleteLifecyclePolicy",
    "ecr:DeleteRepository",
    "ecr:DescribeImages",
    "ecr:GetAuthorizationToken",
    "ecr:GetDownloadUrlForLayer",
    "ecr:GetLifecyclePolicy",
    "ecr:GetLifecyclePolicyPreview",
    "ecr:GetRepositoryPolicy",
    "ecr:InitiateLayerUpload",
    "ecr:ListImages",
    "ecr:ListTagsForResource",
    "ecr:PutImage",
    "ecr:PutImageScanningConfiguration",
    "ecr:PutImageTagMutability",
    "ecr:PutLifecyclePolicy",
    "ecr:SetRepositoryPolicy",
    "ecr:TagResource",
    "ecr:UntagResource",
    "ecr:UploadLayerPart",
    "eks:AssociateAccessPolicy",
    "eks:CreateAccessEntry",
    "eks:CreateAddon",
    "eks:CreateCluster",
    "eks:CreateNodegroup",
    "eks:CreatePodIdentityAssociation",
    "eks:DeleteAccessEntry",
    "eks:DeleteAddon",
    "eks:DeleteCluster",
    "eks:DeleteNodegroup",
    "eks:DeletePodIdentityAssociation",
    "eks:DisassociateAccessPolicy",
    "eks:TagResource",
    "eks:UntagResource",
    "eks:UpdateAccessEntry",
    "eks:UpdateAddon",
    "eks:UpdateClusterConfig",
    "eks:UpdateClusterVersion",
    "eks:UpdateNodegroupConfig",
    "eks:UpdateNodegroupVersion",
    "eks:UpdatePodIdentityAssociation",
    "iam:AttachRolePolicy",
    "iam:CreateRole",
    "iam:DeleteRole",
    "iam:DeleteRolePolicy",
    "iam:DetachRolePolicy",
    "iam:PutRolePolicy",
    "iam:TagRole",
    "iam:UntagRole",
    "iam:UpdateAssumeRolePolicy",
    "logs:CreateLogGroup",
    "logs:DeleteLogGroup",
    "logs:DeleteRetentionPolicy",
    "logs:ListTagsForResource",
    "logs:PutRetentionPolicy",
    "logs:TagResource",
    "logs:UntagResource",
    "secretsmanager:CreateSecret",
    "secretsmanager:DeleteSecret",
    "secretsmanager:GetSecretValue",
    "secretsmanager:ListSecretVersionIds",
    "secretsmanager:PutSecretValue",
    "secretsmanager:RestoreSecret",
    "secretsmanager:TagResource",
    "secretsmanager:UntagResource",
    "secretsmanager:UpdateSecret",
  ]

  ec2_apply_actions = [
    "backup-storage:MountCapsule",
    "backup:CreateBackupPlan",
    "backup:CreateBackupSelection",
    "backup:CreateBackupVault",
    "backup:DeleteBackupPlan",
    "backup:DeleteBackupSelection",
    "backup:DeleteBackupVault",
    "backup:TagResource",
    "backup:UntagResource",
    "backup:UpdateBackupPlan",
    "cloudwatch:DeleteAlarms",
    "cloudwatch:PutMetricAlarm",
    "cloudwatch:TagResource",
    "cloudwatch:UntagResource",
    "ec2:AuthorizeSecurityGroupEgress",
    "ec2:AuthorizeSecurityGroupIngress",
    "ec2:CreateSecurityGroup",
    "ec2:CreateTags",
    "ec2:DeleteSecurityGroup",
    "ec2:GetSecurityGroupsForVpc",
    "ec2:ModifyInstanceMetadataOptions",
    "ec2:RevokeSecurityGroupEgress",
    "ec2:RevokeSecurityGroupIngress",
    "ec2:RunInstances",
    "ec2:StartInstances",
    "ec2:StopInstances",
    "ec2:TerminateInstances",
    "elasticloadbalancing:AddTags",
    "elasticloadbalancing:CreateListener",
    "elasticloadbalancing:CreateLoadBalancer",
    "elasticloadbalancing:CreateTargetGroup",
    "elasticloadbalancing:DeleteListener",
    "elasticloadbalancing:DeleteLoadBalancer",
    "elasticloadbalancing:DeleteTargetGroup",
    "elasticloadbalancing:DeregisterTargets",
    "elasticloadbalancing:ModifyLoadBalancerAttributes",
    "elasticloadbalancing:ModifyTargetGroup",
    "elasticloadbalancing:ModifyTargetGroupAttributes",
    "elasticloadbalancing:RegisterTargets",
    "elasticloadbalancing:RemoveTags",
    "iam:AddRoleToInstanceProfile",
    "iam:AttachRolePolicy",
    "iam:CreateInstanceProfile",
    "iam:CreateRole",
    "iam:DeleteInstanceProfile",
    "iam:DeleteRole",
    "iam:DeleteRolePolicy",
    "iam:DetachRolePolicy",
    "iam:PutRolePolicy",
    "iam:RemoveRoleFromInstanceProfile",
    "iam:TagInstanceProfile",
    "iam:TagRole",
    "iam:UntagInstanceProfile",
    "iam:UntagRole",
    "kms:CreateGrant",
    "kms:Decrypt",
    "kms:GenerateDataKey",
    "kms:RetireGrant",
    "rds:AddTagsToResource",
    "rds:CreateDBInstance",
    "rds:CreateDBSubnetGroup",
    "rds:DeleteDBInstance",
    "rds:DeleteDBSubnetGroup",
    "rds:ModifyDBInstance",
    "rds:ModifyDBSubnetGroup",
    "rds:RemoveTagsFromResource",
    "route53:ChangeTagsForResource",
    "route53:CreateHealthCheck",
    "route53:DeleteHealthCheck",
    "route53:UpdateHealthCheck",
    "secretsmanager:CreateSecret",
    "secretsmanager:DeleteSecret",
    "secretsmanager:GetSecretValue",
    "secretsmanager:PutSecretValue",
    "secretsmanager:RestoreSecret",
    "secretsmanager:TagResource",
    "secretsmanager:UntagResource",
    "secretsmanager:UpdateSecret",
    "sns:CreateTopic",
    "sns:DeleteTopic",
    "sns:SetTopicAttributes",
    "sns:Subscribe",
    "sns:TagResource",
    "sns:Unsubscribe",
    "sns:UntagResource",
    "ssm:GetCommandInvocation",
    "ssm:SendCommand",
  ]
}
