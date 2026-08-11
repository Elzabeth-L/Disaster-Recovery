# 14. Debugging & Observability Manual — Technical Notes

## Diagnostic Shell Command Reference

This document provides developer CLI commands for diagnosing EKS clusters, pod lifecycle issues, ingress status, database connectivity, and logs.

---

## 1. Cluster & Kubeconfig Connection

```bash
# Connect to Primary EKS Cluster (ap-south-1)
aws eks update-kubeconfig --name vaultrix-dr-primary-eks --region ap-south-1

# Connect to DR EKS Cluster (ap-southeast-1)
aws eks update-kubeconfig --name vaultrix-dr-dr-eks --region ap-southeast-1

# Verify Node Status & ARM64 Architecture
kubectl get nodes -o wide
```

---

## 2. Workload & Pod Diagnostics

```bash
# List all resources in namespace notes
kubectl get all -n notes

# Inspect Pod Status & Events (look for CrashLoopBackOff or Pending)
kubectl describe pod -l app.kubernetes.io/name=notes -n notes

# View Live Application Logs
kubectl logs -l app.kubernetes.io/name=notes -n notes --tail=100 -f

# View Live PostgreSQL Database Logs
kubectl logs statefulset/postgres -n notes --tail=100
```

---

## 3. Ingress & Load Balancer Diagnostics

```bash
# Inspect Ingress Rules and ALB Hostname Allocation
kubectl get ingress -n notes

# View AWS Load Balancer Controller DaemonSet Logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=100

# Probe Cluster Ingress Health endpoint directly via curl
ALB_HOST=$(kubectl -n notes get ingress notes -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -i -H "Host: eks.dr.vaultrix.in" "http://${ALB_HOST}/healthz"
curl -i -H "Host: eks.dr.vaultrix.in" "http://${ALB_HOST}/readyz"
```

---

## 4. Database & Secret Diagnostics

```bash
# Check PostgreSQL Readiness probe execution inside container
kubectl exec -it statefulset/postgres -n notes -- pg_isready -U notes -d notes

# Verify Secret Key Injections inside notes namespace (values base64 decoded)
kubectl get secret notes-database -n notes -o jsonpath='{.data.url}' | base64 --decode; echo

# Verify PersistentVolumeClaim status for PostgreSQL
kubectl get pvc -n notes
kubectl describe pv
```
