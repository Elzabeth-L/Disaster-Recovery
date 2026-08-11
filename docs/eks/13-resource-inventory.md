# 13. EKS Resource Inventory — Technical Notes

## Complete Inventory Matrix

```
+-------------------------------------------------------------------------------------------------------------------------------+
| EKS RESOURCE INVENTORY TABLE                                                                                                  |
+-------------------+-----------------------------------+------------+--------------------+---------------------+---------------+
| Layer             | Resource Name                     | AWS / K8s  | Created By         | Purpose             | DR Role       |
+-------------------+-----------------------------------+------------+--------------------+---------------------+---------------+
| Network           | VPC (10.10.0.0/16)                | AWS        | terraform/shared   | Primary VPC         | Active        |
| Network           | VPC (10.20.0.0/16)                | AWS        | terraform/shared   | DR VPC              | Standby       |
| EKS Compute       | vaultrix-dr-primary-eks           | AWS        | eks-platform module| Primary EKS Cluster | Active        |
| EKS Compute       | vaultrix-dr-dr-eks                | AWS        | eks-platform module| DR EKS Cluster      | Standby       |
| Node Capacity     | primary-arm64 (2 x t4g.medium)    | AWS        | aws_eks_node_group | Primary Worker Nodes| Active        |
| Node Capacity     | primary-arm64 (2 x t4g.small)     | AWS        | aws_eks_node_group | DR Worker Nodes     | Standby       |
| Security / IAM    | cluster role                      | AWS        | iam.tf             | EKS Control Role    | Active/Standby|
| Security / IAM    | nodes role                        | AWS        | iam.tf             | Node Worker Role    | Active/Standby|
| Security / IAM    | vpc_cni Pod Identity              | AWS / K8s  | iam.tf             | VPC CNI Networking  | Active/Standby|
| Security / IAM    | ebs_csi Pod Identity              | AWS / K8s  | iam.tf             | EBS Storage Driver  | Active/Standby|
| Security / IAM    | load_balancer_controller Identity | AWS / K8s  | iam.tf             | ALB Provisioner     | Active/Standby|
| Registry          | vaultrix-dr-notes                 | AWS ECR    | eks-platform module| ECR Repo (Backup)   | Shared        |
| Registry          | vaultrix-eks-notes                | GHCR       | Docker Buildx      | Container Registry  | Shared        |
| App Ingress       | AWS Application Load Balancer     | AWS        | AWS LBC (Helm)     | Traffic Ingress     | Active/Standby|
| DNS Routing       | eks.dr.vaultrix.in (CNAME)        | AWS Route53| GHA Workflow       | Domain Router       | CNAME Target  |
| App Secrets       | vaultrix-dr-primary-eks/notes/db  | AWS SM     | terraform/GHA      | Database Creds Safe | Active        |
| App Secrets       | vaultrix-dr-dr-eks/notes/db       | AWS SM     | terraform/GHA      | DR Database Creds   | Standby       |
| Namespace         | notes                             | K8s        | namespace.yaml     | Workload Namespace  | Active/Standby|
| Storage           | encrypted-gp3                     | K8s        | storage-class.yaml | EBS StorageClass    | Active/Standby|
| Microsegmentation | allow-app-ingress                 | K8s        | network-policies.tf| Pod NetworkPolicy   | Active/Standby|
| Workload          | notes (Deployment - 2 Replicas)   | K8s        | app.yaml           | Web App Workload    | Active/Standby|
| Database Workload | postgres (StatefulSet - 1 Replica)| K8s        | postgres.yaml      | PostgreSQL DB       | Active/Standby|
| Workload Service  | notes (Service - ClusterIP 80)    | K8s        | app.yaml           | Internal Web SVC    | Active/Standby|
| Headless Service  | postgres (ClusterIP None)         | K8s        | postgres.yaml      | DB Network Identity | Active/Standby|
| Routing Rule      | notes (Ingress)                   | K8s        | ingress.yaml       | ALB Target Ingress  | Active/Standby|
+-------------------+-----------------------------------+------------+--------------------+---------------------+---------------+
```
