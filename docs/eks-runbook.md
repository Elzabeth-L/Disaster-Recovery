# Primary EKS deployment and cleanup runbook

## Deploy

1. Confirm the primary shared NAT instance and all four EC2/EKS private default routes are healthy.
2. Review the `Primary 1 - EKS infrastructure` Plan workflow summary and current AWS cost estimate.
3. After explicit cost approval, dispatch the same workflow with `Apply`. The protected job applies
   the exact plan artifact created in that run by using GitHub OIDC; it uses no stored AWS keys.
4. Confirm the cluster is Active, two nodes are Ready, and `vpc-cni`, `coredns`, `kube-proxy`, Pod
   Identity agent, and EBS CSI are healthy.
5. Dispatch `Primary 2 - EKS application`. It builds ARM64, pushes an immutable image,
   installs AWS Load Balancer Controller `3.3.0`, creates/reads database credentials in Secrets
   Manager, applies Kustomize, waits for rollouts and ALB health, then publishes DNS.
6. Create a marker note. Delete one app Pod and confirm the service remains available. Delete the
   PostgreSQL Pod and confirm the marker remains after the StatefulSet remounts its EBS volume.
7. Capture `kubectl get nodes,pods,pvc,ingress -A`, add-on status, ALB target health, and test results.

Never print the Secrets Manager value, commit a generated kubeconfig, or replace the immutable image
digest with a mutable tag.

## CloudShell access

Use the Terraform-managed `vaultrix-dr-eks-console-admin` role instead of the AWS account root or the
GitHub deployment role. The role is an EKS cluster administrator only in the two project clusters.

Primary cluster:

```bash
aws eks update-kubeconfig \
  --name vaultrix-dr-primary-eks \
  --region ap-south-1 \
  --role-arn arn:aws:iam::598120810297:role/vaultrix-dr-eks-console-admin
kubectl get nodes
```

DR cluster:

```bash
aws eks update-kubeconfig \
  --name vaultrix-dr-dr-eks \
  --region ap-southeast-1 \
  --role-arn arn:aws:iam::598120810297:role/vaultrix-dr-eks-console-admin
kubectl get nodes
```

## Troubleshoot private-node egress

Test DNS, ECR token/API access, ECR layer pulls through S3, STS, EKS Auth/Pod Identity, EC2 and ELB
APIs, the Helm repository, and public package endpoints. Confirm the NAT instance is running, source/
destination checking is disabled, forwarding/firewall initialization succeeded, and both private EKS
route tables point to its network interface. If repeated tests show it is unreliable, stop and obtain
a reviewed plan/cost approval before switching shared `egress_mode` to `nat_gateway`.

## Backup-first cleanup

Cleanup is destructive and requires a separate reviewed change and approval.

1. Stop writes and capture the marker value. Create and verify the required PostgreSQL/volume backup
   before deleting the PVC or EBS volume.
2. Change the Ingress annotation `deletion_protection.enabled` to `false`, apply it, delete the Ingress,
   and wait until the ALB and its security groups are gone. Delete `eks.dr.vaultrix.in`.
3. Decide explicitly whether to retain or delete the PostgreSQL PVC/PV/EBS volume. `Retain` is the
   default reclaim policy, so deleting Kubernetes objects does not stop EBS charges by itself.
4. Apply the EKS Terraform root once with `cluster_deletion_protection=false` while
   `deployment_enabled=true`.
5. Review a second plan with `deployment_enabled=false`, approve it, and apply it to remove the node
   group, add-ons, cluster, ECR/secret containers where permitted, IAM roles, and log group.
6. Verify with AWS inventory that no EKS cluster/node group, ALB/target group, orphan ENI/security
   group, unwanted EBS volume/snapshot, or ECR image remains. Retain only approved recovery data.
7. Record final resource inventory, backup identifiers, DNS state, and measured cost window.

Do not destroy shared networking or the NAT instance while another workload depends on it.
