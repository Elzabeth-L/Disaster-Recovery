# 06. Kubernetes Application Specifications — Technical Notes

## 1. Overview & Resource Inventory

The Kubernetes workloads reside inside namespace `notes` ([`kubernetes/base/namespace.yaml`](file:///c:/Users/smine/Disaster-Recovery/kubernetes/base/namespace.yaml)).

```
+---------------------------------------------------------------------------------------------------+
| KUBERNETES MANIFEST INVENTORY                                                                     |
+---------------------+-------------------+---------------------+-----------------------------------+
| Kind                | Name              | API Version         | Purpose                           |
+---------------------+-------------------+---------------------+-----------------------------------+
| Namespace           | notes             | v1                  | Isolated workload namespace       |
| StorageClass        | encrypted-gp3     | storage.k8s.io/v1   | Encrypted EBS gp3 volumes         |
| ServiceAccount      | notes             | v1                  | Application Pod identity context  |
| PodDisruptionBudget | notes             | policy/v1           | High availability (minAvailable=1)|
| Deployment          | notes             | apps/v1             | 2-replica Flask web application   |
| Service             | notes             | v1                  | ClusterIP Service (Port 80)       |
| StatefulSet         | postgres          | apps/v1             | 1-replica PostgreSQL 17.6 database|
| Service             | postgres          | v1                  | Headless Service (ClusterIP None) |
| Ingress             | notes             | networking.k8s.io/v1| AWS ALB Controller ingress rule   |
| NetworkPolicy       | allow-app-ingress | networking.k8s.io/v1| Restricts ingress to notes pods   |
| NetworkPolicy       | allow-postgres... | networking.k8s.io/v1| Restricts port 5432 to notes app  |
+---------------------+-------------------+---------------------+-----------------------------------+
```

---

## 2. Web Application Deployment Spec (`kubernetes/base/app.yaml`)

- **Replicas**: `2`
- **Pod Disruption Budget**: `minAvailable: 1` (Guarantees at least 1 pod remains running during node upgrades).
- **Topology Spread Constraints**:
  ```yaml
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          app.kubernetes.io/name: notes
  ```
  Distributes the two application pods across distinct Availability Zones (AZs) for multi-AZ fault tolerance.
- **Security Context**:
  - `runAsNonRoot: true`, `runAsUser: 10001`, `runAsGroup: 10001`, `fsGroup: 10001`.
  - `readOnlyRootFilesystem: true` (Prevents malware from modifying container binaries; `/tmp` mounted as emptyDir).
  - `capabilities: drop: ["ALL"]`, `allowPrivilegeEscalation: false`.
- **Health Probes**:
  - `readinessProbe`: HTTP GET `/readyz` on port 8080 (initial delay: 5s, period: 5s). Evaluates database connectivity.
  - `livenessProbe`: HTTP GET `/healthz` on port 8080 (initial delay: 15s, period: 10s). Fast HTTP 200 check.
- **Resource Limits**:
  - CPU requests: `50m`, limits: `300m`.
  - Memory requests: `96Mi`, limits: `256Mi`.

---

## 3. Database StatefulSet Spec (`kubernetes/base/postgres.yaml`)

- **Replicas**: `1`
- **Image**: `postgres:17.6-alpine`
- **Headless Service**: `name: postgres`, `clusterIP: None`. Headless service provides stable network identity (`postgres.notes.svc.cluster.local`) required for StatefulSet volume binding.
- **Volume Claim Template**:
  ```yaml
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: encrypted-gp3
        resources:
          requests:
            storage: 8Gi
  ```
- **StorageClass (`kubernetes/base/storage-class.yaml`)**:
  - Provisioner: `ebs.csi.aws.com`
  - Parameters: `type: gp3`, `encrypted: "true"`
  - `volumeBindingMode: WaitForFirstConsumer` (Ensures EBS volume is created in the exact AZ where the PostgreSQL pod is scheduled).
- **Health Probes**:
  - `readinessProbe` & `livenessProbe`: Exec command `pg_isready -U $POSTGRES_USER -d $POSTGRES_DB`.

---

## 4. Ingress Specification (`kubernetes/base/ingress.yaml`)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: notes
  namespace: notes
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /healthz
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
spec:
  ingressClassName: alb
  rules:
    - host: eks.dr.vaultrix.in
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: notes
                port:
                  number: 80
```

- **Target Type (`ip`)**: Direct pod routing mode. The AWS ALB forwards HTTP traffic directly to the private Pod IP addresses of the `notes` pods, bypassing node NodePort translation for lower latency and better load balancing.
