output "contract_version" { value = local.contract_version }
output "deployment_enabled" { value = var.deployment_enabled }
output "cluster_name" { value = try(module.eks_platform[0].cluster_name, null) }
output "cluster_endpoint" { value = try(module.eks_platform[0].cluster_endpoint, null) }
output "database_secret_arn" { value = try(module.eks_platform[0].database_secret_arn, null) }
output "load_balancer_controller_role_arn" { value = try(module.eks_platform[0].load_balancer_controller_role_arn, null) }
