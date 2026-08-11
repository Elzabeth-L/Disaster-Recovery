# 12. Developer Story: How Everything Connects — Technical Notes

## Story-Driven Architectural Breakdown

This guide explains the entire EKS architecture through plain-language developer questions.

---

## 1. "When I push code to `applications/eks-app/`, what happens?"

1. **Pull Request Validation** (`eks-app-ci.yml`):
   - GitHub Actions checks out code, runs `pytest` inside Python 3.13 environment.
   - Builds an `ARM64` container image locally without pushing to verify Dockerfile syntax.
   - Runs `kubectl kustomize kubernetes/overlays/primary` to verify Kustomize manifest syntax. Fails if `replace-me` tag substitution is broken.
2. **Container Build & Registry Push** (`eks-app-deploy.yml`):
   - Once merged, running the deployment workflow triggers Docker Buildx.
   - Pushes tag `ghcr.io/elzabeth-l/vaultrix-eks-notes:<git-sha>` to GHCR.
   - Captures the exact immutable image digest `sha256:...`.
3. **Kubernetes Rollout**:
   - Updates `kubernetes/overlays/primary/kustomization.yaml` substituting `digest: <sha256>`.
   - Executes `kubectl apply -k kubernetes/overlays/primary`.
   - Kubernetes Deployment `notes` performs a zero-downtime rolling update across the 2 pod replicas.
4. **Ingress & Route 53 Publication**:
   - Probes `http://<ALB_DNS>/healthz` until HTTP 200 is verified.
   - Updates Route 53 CNAME record `eks.dr.vaultrix.in` to point to the AWS Application Load Balancer hostname.

---

## 2. "When a user opens `http://eks.dr.vaultrix.in`, what happens?"

1. **DNS Lookup**: Route 53 CNAME record `eks.dr.vaultrix.in` resolves to the AWS ALB public hostname in `ap-south-1`.
2. **ALB Routing**: Public internet traffic hits ALB Port 80. ALB evaluates Ingress rules and routes HTTP traffic directly to the private IP address of one of the `notes` application pods (`target-type: ip`).
3. **Application Execution**: The Flask container process reads environment variable `DATABASE_URL` (injected from Kubernetes secret `notes-database`).
4. **Database Query**: Flask connects over TCP port 5432 to `postgres.notes.svc.cluster.local` (the headless service pointing to PostgreSQL StatefulSet `postgres`).
5. **Response**: PostgreSQL returns records from `notes` table; Flask renders Jinja2 HTML dashboard and returns HTTP 200 OK to ALB $\to$ User Browser.

---

## 3. "When a Pod, Node, or Regional Disaster occurs, what happens?"

- **Scenario A (Pod Death)**: Kubernetes Deployment detects container exit. ReplicaSet launches a replacement pod. PodDisruptionBudget `minAvailable: 1` ensures at least 1 pod is active. Service continues routing traffic seamlessly.
- **Scenario B (Node Crash)**: Node becomes `NotReady`. Kubernetes Scheduler reschedules evicted pods onto the remaining healthy worker node.
- **Scenario C (Primary Regional Failure)**:
  - Operator declarations or DR workflow (`.github/workflows/dr-drill.yml`) triggers EKS cutover.
  - Workflow deploys Kustomize overlay `kubernetes/overlays/dr` to DR cluster `vaultrix-dr-dr-eks` in Singapore (`ap-southeast-1`).
  - Seeds database snapshot into Singapore PostgreSQL StatefulSet.
  - Updates Route 53 CNAME record `eks.dr.vaultrix.in` to point to Singapore DR ALB hostname.
  - Users are served out of Singapore!
