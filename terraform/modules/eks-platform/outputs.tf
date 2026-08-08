output "cluster_name" { value = aws_eks_cluster.this.name }
output "cluster_endpoint" { value = aws_eks_cluster.this.endpoint }
output "cluster_version" { value = aws_eks_cluster.this.version }
output "ecr_repository_url" { value = aws_ecr_repository.notes.repository_url }
output "database_secret_arn" { value = aws_secretsmanager_secret.database.arn }
output "load_balancer_controller_role_arn" { value = aws_iam_role.load_balancer_controller.arn }
output "addon_versions" { value = { for name, addon in aws_eks_addon.selected : name => addon.addon_version } }
