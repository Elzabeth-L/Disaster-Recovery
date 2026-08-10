resource "aws_iam_user" "eks_operator" {
  name          = "vaultrix-dr-eks-operator"
  force_destroy = false

  tags = {
    Name   = "vaultrix-dr-eks-operator"
    Scope  = "eks"
    Access = "human-operator"
  }
}

data "aws_iam_policy_document" "eks_operator" {
  statement {
    sid       = "UseCloudShell"
    effect    = "Allow"
    actions   = ["cloudshell:*"]
    resources = ["*"]
  }

  statement {
    sid       = "ListClusters"
    effect    = "Allow"
    actions   = ["eks:ListClusters"]
    resources = ["*"]
  }

  statement {
    sid    = "ConnectToProjectClusters"
    effect = "Allow"
    actions = [
      "eks:AccessKubernetesApi",
      "eks:DescribeCluster",
    ]
    resources = [
      "arn:aws:eks:ap-south-1:${var.expected_aws_account_id}:cluster/vaultrix-dr-primary-eks",
      "arn:aws:eks:ap-southeast-1:${var.expected_aws_account_id}:cluster/vaultrix-dr-dr-eks",
    ]
  }

  statement {
    sid       = "ChangeOwnPassword"
    effect    = "Allow"
    actions   = ["iam:ChangePassword"]
    resources = [aws_iam_user.eks_operator.arn]
  }

  statement {
    sid       = "ReadPasswordPolicy"
    effect    = "Allow"
    actions   = ["iam:GetAccountPasswordPolicy"]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "eks_operator" {
  name   = "vaultrix-dr-eks-operator"
  user   = aws_iam_user.eks_operator.name
  policy = data.aws_iam_policy_document.eks_operator.json
}

resource "aws_iam_user" "ec2_operator" {
  name          = "vaultrix-dr-ec2-operator"
  force_destroy = false

  tags = {
    Name   = "vaultrix-dr-ec2-operator"
    Scope  = "ec2"
    Access = "human-operator"
    Owner  = "gokulk18"
  }
}

data "aws_iam_policy_document" "ec2_operator" {
  statement {
    sid       = "UseCloudShell"
    effect    = "Allow"
    actions   = ["cloudshell:*"]
    resources = ["*"]
  }

  statement {
    sid    = "DiscoverProjectInstances"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ssm:DescribeInstanceInformation",
      "ssm:DescribeInstanceProperties",
      "ssm:DescribeSessions",
      "ssm:GetConnectionStatus",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "StartProjectInstanceSessions"
    effect    = "Allow"
    actions   = ["ssm:StartSession"]
    resources = ["arn:aws:ec2:*:${var.expected_aws_account_id}:instance/*"]

    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Project"
      values   = [local.project]
    }

    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Name"
      values = [
        "vaultrix-dr-primary-ec2-instance",
        "vaultrix-dr-dr-ec2-instance",
      ]
    }
  }

  statement {
    sid       = "UseDefaultSessionDocument"
    effect    = "Allow"
    actions   = ["ssm:StartSession"]
    resources = ["arn:aws:ssm:*:${var.expected_aws_account_id}:document/SSM-SessionManagerRunShell"]
  }

  statement {
    sid       = "ManageOwnSessions"
    effect    = "Allow"
    actions   = ["ssm:ResumeSession", "ssm:TerminateSession", "ssmmessages:OpenDataChannel"]
    resources = ["arn:aws:ssm:*:*:session/$${aws:userid}-*"]
  }

  statement {
    sid       = "ChangeOwnPassword"
    effect    = "Allow"
    actions   = ["iam:ChangePassword"]
    resources = [aws_iam_user.ec2_operator.arn]
  }

  statement {
    sid       = "ReadPasswordPolicy"
    effect    = "Allow"
    actions   = ["iam:GetAccountPasswordPolicy"]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "ec2_operator" {
  name   = "vaultrix-dr-ec2-session-manager"
  user   = aws_iam_user.ec2_operator.name
  policy = data.aws_iam_policy_document.ec2_operator.json
}
