# 07. Network Flow & AWS Load Balancer Controller — Technical Notes

## 1. Complete End-to-End Ingress Path

Request processing for the EKS application flows across 8 distinct networking layers:

```
[ User Browser ]
       │
       │ 1. HTTP GET http://eks.dr.vaultrix.in
       v
[ Amazon Route 53 DNS ]
       │
       │ 2. Returns CNAME pointing to AWS ALB Hostname
       v
[ AWS Application Load Balancer (Public Subnets) ]
       │
       │ 3. Matches Ingress Rule (Host: eks.dr.vaultrix.in, Path: /)
       v
[ Target Group (Target Type: IP) ]
       │
       │ 4. Forwards TCP 8080 traffic directly to Pod Private IP (VPC CNI)
       v
[ Kubernetes Ingress / Service: notes (Port 80) ]
       │
       │ 5. Routes to Application Pod Replica
       v
[ Application Pod Container (app.py) ]
       │
       │ 6. Evaluates DATABASE_URL secret environment variable
       v
[ Headless Service: postgres (postgres.notes.svc.cluster.local:5432) ]
       │
       │ 7. Routes TCP 5432 query to PostgreSQL StatefulSet Pod
       v
[ PostgreSQL Pod Container (postgres:17.6-alpine) ]
       │
       │ 8. Reads/Writes data to EBS gp3 PersistentVolume (/var/lib/postgresql/data)
       v
[ Returns HTTP 200 OK + Rendered JSON/HTML to User ]
```

---

## 2. Deep Dive: AWS Load Balancer Controller Integration

The AWS Load Balancer Controller (`helm` release `aws-load-balancer-controller` version `3.3.0` in `kube-system`) reconciles Kubernetes Ingress resources with AWS Elastic Load Balancing API objects.

### Operational Sequence:
1. Developer applies `Ingress` resource with `ingressClassName: alb`.
2. AWS Load Balancer Controller watches the Kubernetes API server and detects the Ingress resource.
3. Using its Pod Identity IAM role (`aws_iam_role.load_balancer_controller`), it issues AWS API calls:
   - `elasticloadbalancing:CreateLoadBalancer` in public subnets.
   - `elasticloadbalancing:CreateTargetGroup` with target type `ip`.
   - `elasticloadbalancing:CreateListener` on port 80.
4. It inspects `Service` `notes` endpoints and registers pod private IPs (`10.10.x.x`) directly into the ALB Target Group.
5. Sets ALB target health check path to `/healthz`.

---

## 3. NetworkPolicy Ingress Rules (`kubernetes/base/network-policies.yaml`)

NetworkPolicies enforce strict in-cluster microsegmentation using the AWS VPC CNI NetworkPolicy engine (`enableNetworkPolicy = "true"`):

### Rule A: Restrict Ingress to Application Pods
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app-ingress
  namespace: notes
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: notes
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 8080
```

### Rule B: Restrict Database Ingress Strictly to Application Pods
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-postgres-from-app
  namespace: notes
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: postgres
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: notes
      ports:
        - protocol: TCP
          port: 5432
```
- **Security Boundary**: Blocks all other namespaces or unauthorized pods from connecting to PostgreSQL port 5432.
