# Primary EKS

This root owns the continuously running primary EKS platform. Its state is isolated at
`primary/eks/terraform.tfstate`. It only consumes published outputs from the primary and global
shared states.

The default configuration creates no resources. A reviewed plan or apply must explicitly set
`deployment_enabled=true` and `cost_acknowledgement=APPROVE_PRIMARY_EKS_COSTS`.

The cluster uses two private ARM64 on-demand nodes, the existing NAT instance for egress, EKS Pod
Identity, EBS CSI storage, an ECR repository, and a Secrets Manager container. The secret value is
created operationally and is never stored in Terraform state.
