# 01. EKS Infrastructure Provisioning — Technical Notes

## 1. Overview & Terraform Architecture

The EKS infrastructure is provisioned using Terraform via the reusable module `terraform/modules/eks-platform`. Infrastructure state is strictly isolated across regional root configurations:
- **Primary Root**: [`terraform/environments/primary/eks`](file:///c:/Users/smine/Disaster-Recovery/terraform/environments/primary/eks) (Region `ap-south-1`)
- **DR Root**: [`terraform/environments/dr/eks`](file:///c:/Users/smine/Disaster-Recovery/terraform/environments/dr/eks) (Region `ap-southeast-1`)

```
+-----------------------------------------------------------------------------------------------+
| EKS TERRAFORM STATE BOUNDARIES                                                                |
+--------------------------+--------------------+-----------------------------------------------+
| Environment              | State Key          | Shared Remote Dependencies Consumed           |
+--------------------------+--------------------+-----------------------------------------------+
| Primary EKS Root         | primary/eks/...    | primary/shared (EKS Subnets), global/shared   |
| (ap-south-1)             |                    | (Route 53 Zone, OIDC IAM Role)                |
+--------------------------+--------------------+-----------------------------------------------+
| DR EKS Root              | dr/eks/...         | dr/shared (EKS Subnets), global/shared        |
| (ap-southeast-1)         |                    | (Route 53 Zone, OIDC IAM Role)                |
+--------------------------+--------------------+-----------------------------------------------+
```

---

## 2. Networking & Subnet Architecture

EKS cluster control plane endpoints and worker node capacity reside inside dedicated private EKS subnets provisioned by the regional network module (`terraform/modules/regional-network`):
- **VPC IPv4 CIDR**: `10.10.0.0/16` (Primary) / `10.20.0.0/16` (DR)
- **EKS Private Subnets**: `10.10.2.0/24` (AZ a) and `10.10.12.0/24` (AZ b)
- **Public Subnets**: Used by AWS Load Balancer Controller to dynamically provision public internet-facing ALBs.

---

## 3. Deep Dive: EKS Platform Module (`terraform/modules/eks-platform/main.tf`)

### A. EKS Cluster Control Plane (`aws_eks_cluster.this`)
- **Version**: Kubernetes `1.32` (`var.kubernetes_version`)
- **Authentication Mode**: `API` (`access_config.authentication_mode = "API"`). Legacy ConfigMap `aws-auth` is disabled.
- **Log Types Enabled**: `api`, `audit`, `authenticator`, `controllerManager`, `scheduler`. Retained for 30 days in CloudWatch Log Group `/aws/eks/<name_prefix>/cluster`.
- **VPC Endpoint Access**: `endpoint_private_access = true`, `endpoint_public_access = true`.

---

### B. Managed Node Groups (`aws_eks_node_group.primary`)
- **AMI Type**: `AL2023_ARM_64_STANDARD` (Amazon Linux 2023 ARM64 architecture).
- **Capacity Type**: `ON_DEMAND`.
- **Primary Node Sizing**: Instance types `["t4g.medium"]`, desired size `2`, min size `2`, max size `3`.
- **DR Node Sizing**: Instance types `["t4g.small"]`, desired size `2`, min size `2`, max size `3`.
- **Storage**: 30 GB `gp3` root volume per worker node.

---

### C. EKS Add-ons & Pod Identity Associations

The module splits EKS Add-on creation into two distinct phases to handle node dependency ordering:

#### Phase 1: Bootstrap Add-ons (`aws_eks_addon.bootstrap`)
Created **before** node group launch:
1. `eks-pod-identity-agent`: Enables EKS Pod Identity credential routing.
2. `kube-proxy`: K8s network proxy on each node.
3. `vpc-cni`: AWS VPC Container Network Interface (`enableNetworkPolicy = "true"`).

#### Phase 2: Post-Node Add-ons (`aws_eks_addon.post_node`)
Created **after** worker nodes join the cluster (`depends_on = [aws_eks_node_group.primary]`):
1. `aws-ebs-csi-driver`: Manages EBS volume creation for `PersistentVolumeClaims`.
2. `coredns`: In-cluster DNS resolution.

---

## 4. Infrastructure Workflow (`.github/workflows/eks-platform.yml`)

Manages Terraform planning and execution for the primary EKS cluster:
- **Trigger**: `workflow_dispatch` with inputs `operation: [Plan, Apply]`.
- **Authentication**: Assumes AWS IAM OIDC role `vars.AWS_EKS_PLAN_ROLE_ARN` / `vars.AWS_EKS_APPLY_ROLE_ARN`.
- **Cost Protection Gate**: Requires variable `cost_acknowledgement = "APPROVE_PRIMARY_EKS_COSTS"`.
