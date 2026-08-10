# 15. Progressive Developer Learning Guide — Technical Notes

## 12-Level Progressive Learning Pathway

This structured curriculum guides developers from basic Kubernetes concepts up through multi-region EKS Disaster Recovery cutover.

---

### Level 1: What is EKS?
- **Concept**: AWS Managed Kubernetes Control Plane. AWS handles K8s API server availability (`etcd`, scheduler, controller manager); you manage worker nodes and container workloads.
- **In Repository**: [`terraform/modules/eks-platform/main.tf`](file:///c:/Users/smine/Disaster-Recovery/terraform/modules/eks-platform/main.tf) provisions `aws_eks_cluster.this` running K8s `1.32`.

---

### Level 2: What is a Kubernetes Pod?
- **Concept**: The smallest deployable unit in Kubernetes. Runs one or more tightly coupled containers sharing network and storage namespaces.
- **In Repository**: [`applications/eks-app/Dockerfile`](file:///c:/Users/smine/Disaster-Recovery/applications/eks-app/Dockerfile) builds the Python 3.13 Flask container running as UID `10001`.

---

### Level 3: Deployment $\to$ ReplicaSet $\to$ Pod
- **Concept**: Deployments manage declarative updates for Pods via intermediate ReplicaSets.
- **In Repository**: [`kubernetes/base/app.yaml`](file:///c:/Users/smine/Disaster-Recovery/kubernetes/base/app.yaml) defines Deployment `notes` (`replicas: 2`).

---

### Level 4: Service $\to$ Pod
- **Concept**: Abstract layer exposing a group of Pods as a network service.
- **In Repository**: Service `notes` (`port: 80`, `targetPort: http`) routes traffic to pods labeled `app.kubernetes.io/name: notes`.

---

### Level 5: Ingress $\to$ AWS Load Balancer Controller $\to$ Service
- **Concept**: Manages external HTTP routing into cluster services.
- **In Repository**: [`kubernetes/base/ingress.yaml`](file:///c:/Users/smine/Disaster-Recovery/kubernetes/base/ingress.yaml) configures `ingressClassName: alb` and `target-type: ip`.

---

### Level 6: EKS IAM Authentication & Pod Identity
- **Concept**: Keyless AWS identity injection for Pods without static credentials.
- **In Repository**: `aws_eks_pod_identity_association` binds IAM roles to `aws-load-balancer-controller`, `ebs-csi-controller-sa`, and `aws-node`.

---

### Level 7: Terraform $\to$ EKS Infrastructure
- **Concept**: Infrastructure-as-Code declaring VPCs, subnets, and clusters.
- **In Repository**: [`terraform/environments/primary/eks`](file:///c:/Users/smine/Disaster-Recovery/terraform/environments/primary/eks) invokes `eks-platform` module.

---

### Level 8: GitHub Actions CI $\to$ Container Registry
- **Concept**: Continuous integration building container images on code push.
- **In Repository**: [`.github/workflows/eks-app-ci.yml`](file:///c:/Users/smine/Disaster-Recovery/.github/workflows/eks-app-ci.yml) and [`.github/workflows/eks-app-deploy.yml`](file:///c:/Users/smine/Disaster-Recovery/.github/workflows/eks-app-deploy.yml).

---

### Level 9: Kustomize Manifest Reconciliation
- **Concept**: Overlaying environment-specific image tags and patches onto base Kubernetes manifests.
- **In Repository**: `kubernetes/base` combined with `kubernetes/overlays/primary` or `kubernetes/overlays/dr`.

---

### Level 10: Complete Application Lifecycle
- **Concept**: Tracing code push $\to$ Docker Buildx $\to$ GHCR push $\to$ `kubectl apply` $\to$ ALB target registration $\to$ Route 53 update.

---

### Level 11: Multi-Region Standby Architecture
- **Concept**: Primary active cluster in `ap-south-1` (Mumbai) paired with pre-warmed standby pilot cluster in `ap-southeast-1` (Singapore).

---

### Level 12: EKS Disaster Recovery & CNAME Cutover
- **Concept**: Triggering DR workflow, restoring PostgreSQL state, probing health endpoints, and updating Route 53 CNAME record `eks.dr.vaultrix.in`.
