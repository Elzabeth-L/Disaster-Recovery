# 10. Disaster Recovery Drill Workflows — Technical Notes

## 1. Overview & Workflow Trigger

EKS Disaster Recovery drills are driven by the unified workflow [`.github/workflows/dr-drill.yml`](file:///c:/Users/smine/Disaster-Recovery/.github/workflows/dr-drill.yml). The workflow provides an interactive `workflow_dispatch` interface with four operational choices.

---

## 2. Operations Breakdown

### Operation A: `Deploy or refresh DR applications` (`deploy-eks` job)

1. **Capture Primary Notes Snapshot**:
   ```bash
   curl --fail --retry 6 --retry-delay 5 http://eks.dr.vaultrix.in/api/notes -o "${RUNNER_TEMP}/notes.json"
   ```
2. **Discover Primary Image Digest**:
   Connects to primary cluster `vaultrix-dr-primary-eks` via `aws eks update-kubeconfig` and extracts container image digest (`sha256:...`).
3. **Connect to DR Cluster**:
   Connects to `vaultrix-dr-dr-eks` in region `ap-southeast-1`.
4. **Install AWS Load Balancer Controller**:
   Uses Helm to install/upgrade `aws-load-balancer-controller` version `3.3.0` in namespace `kube-system`.
5. **Populate DR Database Secrets**:
   Fetches or generates secret `vaultrix-dr-dr-eks/notes/database` in AWS Secrets Manager and creates Kubernetes secret `notes-database` in namespace `notes`.
6. **Deploy Immutable Image**:
   Substitutes `digest: <primary_digest>` in `kubernetes/overlays/dr/kustomization.yaml` and executes `kubectl apply -k kubernetes/overlays/dr`.
7. **Seed Data & Publish Diagnostic DNS**:
   - Deletes existing DR notes via `DELETE http://<DR_ALB>/api/notes/<id>`.
   - Seeds captured primary notes payload via `POST http://<DR_ALB>/api/notes`.
   - Creates Route 53 diagnostic CNAME record `eks-dr.dr.vaultrix.in` pointing to DR ALB.

---

### Operation B: `Failover to DR` (`cutover-eks` job)

Requires `inputs.confirmation == 'DEMONSTRATE_DR'`:

1. **Validate Diagnostic Endpoint**:
   Probes `http://eks-dr.dr.vaultrix.in/healthz` to confirm DR EKS readiness.
2. **Execute CNAME Traffic Cutover**:
   Constructs Route 53 change batch payload:
   - Sets `eks-primary.dr.vaultrix.in` $\to$ Primary ALB Hostname.
   - Sets `eks.dr.vaultrix.in` $\to$ DR ALB Hostname.
   - Issues `aws route53 change-resource-record-sets` and waits via `aws route53 wait resource-record-sets-changed`.
3. **Verify Public Endpoint**:
   Executes `curl http://eks.dr.vaultrix.in/healthz` and `http://eks.dr.vaultrix.in/api/notes`.

---

### Operation C: `Failback to primary` (`cutover-eks` job)

Requires `inputs.confirmation == 'DEMONSTRATE_DR'`:

1. Retrieves original primary CNAME target from `eks-primary.dr.vaultrix.in`.
2. Updates `eks.dr.vaultrix.in` CNAME record back to Primary ALB Hostname.
3. Probes `http://eks.dr.vaultrix.in/healthz` until Primary response is verified.

---

### Operation D: `Remove DR applications` (`cleanup-eks` job)

Requires `inputs.confirmation == 'CLEANUP_DR_APPS'`:

1. Patches PersistentVolumes to `persistentVolumeReclaimPolicy: Delete`.
2. Runs `kubectl delete -k kubernetes/overlays/dr --ignore-not-found --wait=true`.
3. Uninstalls `aws-load-balancer-controller` Helm release.
4. Deletes diagnostic Route 53 CNAME records `eks-dr.dr.vaultrix.in` and `eks-primary.dr.vaultrix.in`.
