data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.name_prefix}-cluster"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "nodes" {
  name               = "${var.name_prefix}-nodes"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "nodes" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
  ])

  role       = aws_iam_role.nodes.name
  policy_arn = each.value
}

data "aws_iam_policy_document" "pods_assume_role" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vpc_cni" {
  name               = "${var.name_prefix}-vpc-cni"
  assume_role_policy = data.aws_iam_policy_document.pods_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  role       = aws_iam_role.vpc_cni.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.name_prefix}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.pods_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role" "load_balancer_controller" {
  name               = "${var.name_prefix}-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.pods_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "load_balancer_controller" {
  statement {
    sid       = "CreateServiceLinkedRole"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
    }
  }

  statement {
    sid = "ReadInfrastructure"
    actions = [
      "ec2:DescribeAccountAttributes", "ec2:DescribeAddresses", "ec2:DescribeAvailabilityZones",
      "ec2:DescribeCoipPools", "ec2:DescribeInstances", "ec2:DescribeInternetGateways",
      "ec2:DescribeIpamPools", "ec2:DescribeRouteTables", "ec2:GetCoipPoolUsage",
      "ec2:GetSecurityGroupsForVpc",
      "ec2:DescribeNetworkInterfaces", "ec2:DescribeSecurityGroups", "ec2:DescribeSubnets",
      "ec2:DescribeTags", "ec2:DescribeVpcPeeringConnections", "ec2:DescribeVpcs",
      "elasticloadbalancing:DescribeCapacityReservation", "elasticloadbalancing:DescribeListenerAttributes",
      "elasticloadbalancing:DescribeListenerCertificates", "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancerAttributes", "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeRules", "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeTags", "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetGroups", "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTrustStores",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ManageLoadBalancers"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress", "ec2:CreateSecurityGroup", "ec2:CreateTags",
      "ec2:DeleteSecurityGroup", "ec2:DeleteTags", "ec2:RevokeSecurityGroupIngress",
      "elasticloadbalancing:AddTags", "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:CreateTargetGroup", "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer", "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:DeleteTargetGroup", "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:AddListenerCertificates", "elasticloadbalancing:ModifyCapacityReservation",
      "elasticloadbalancing:ModifyIpPools", "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyListenerAttributes",
      "elasticloadbalancing:ModifyLoadBalancerAttributes", "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:ModifyTargetGroup", "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets", "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:RemoveTags", "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetRulePriorities", "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets", "elasticloadbalancing:SetWebAcl",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "load_balancer_controller" {
  name   = "aws-load-balancer-controller"
  role   = aws_iam_role.load_balancer_controller.id
  policy = data.aws_iam_policy_document.load_balancer_controller.json
}
