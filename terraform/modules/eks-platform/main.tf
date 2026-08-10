data "aws_eks_addon_version" "selected" {
  for_each = toset([
    "aws-ebs-csi-driver",
    "coredns",
    "eks-pod-identity-agent",
    "kube-proxy",
    "vpc-cni",
  ])

  addon_name         = each.value
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

locals {
  bootstrap_addons = toset([
    "eks-pod-identity-agent",
    "kube-proxy",
    "vpc-cni",
  ])

  post_node_addons = toset([
    "aws-ebs-csi-driver",
    "coredns",
  ])
}

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.name_prefix}/cluster"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_eks_cluster" "this" {
  name                      = var.name_prefix
  role_arn                  = aws_iam_role.cluster.arn
  version                   = var.kubernetes_version
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  deletion_protection       = var.deletion_protection

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  upgrade_policy {
    support_type = "STANDARD"
  }

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
    subnet_ids              = var.private_subnet_ids
  }

  depends_on = [
    aws_cloudwatch_log_group.cluster,
    aws_iam_role_policy_attachment.cluster,
  ]

  tags = var.tags
}

resource "aws_eks_access_entry" "github_apply" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.github_apply_role_arn
  type          = "STANDARD"
  tags          = var.tags
}

resource "aws_eks_access_policy_association" "github_apply" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.github_apply_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_entry" "console_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.console_admin_role_arn
  type          = "STANDARD"
  tags          = var.tags
}

resource "aws_eks_access_policy_association" "console_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.console_admin_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.console_admin]
}

resource "aws_eks_node_group" "primary" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "primary-arm64"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids
  ami_type        = "AL2023_ARM_64_STANDARD"
  capacity_type   = "ON_DEMAND"
  instance_types  = var.node_instance_types
  disk_size       = 30

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = 2
    max_size     = 3
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_eks_addon.bootstrap,
    aws_eks_pod_identity_association.vpc_cni,
    aws_iam_role_policy_attachment.nodes,
  ]
  tags = var.tags
}

resource "aws_eks_addon" "bootstrap" {
  for_each = {
    for name, version in data.aws_eks_addon_version.selected : name => version
    if contains(local.bootstrap_addons, name)
  }

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  addon_version               = each.value.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  configuration_values = each.key == "vpc-cni" ? jsonencode({
    enableNetworkPolicy = "true"
  }) : null

  tags = var.tags
}

resource "aws_eks_addon" "post_node" {
  for_each = {
    for name, version in data.aws_eks_addon_version.selected : name => version
    if contains(local.post_node_addons, name)
  }

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  addon_version               = each.value.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_node_group.primary]
  tags       = var.tags
}

resource "aws_eks_pod_identity_association" "vpc_cni" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "aws-node"
  role_arn        = aws_iam_role.vpc_cni.arn
}

resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi.arn
}

resource "aws_eks_pod_identity_association" "load_balancer_controller" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.load_balancer_controller.arn
}

resource "aws_ecr_repository" "notes" {
  name                 = "vaultrix-dr-notes"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "notes" {
  repository = aws_ecr_repository.notes.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Retain the newest 20 release images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_secretsmanager_secret" "database" {
  name                    = "${var.name_prefix}/notes/database"
  description             = "Runtime PostgreSQL credentials; populated by the protected deployment workflow."
  recovery_window_in_days = 7
  tags                    = var.tags
}
