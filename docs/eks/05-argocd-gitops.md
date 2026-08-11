# 05. Deployment Reconciliation & GitOps Model — Technical Notes

## 1. GitOps & Declarative Manifest Reconciliation

The EKS application deployment architecture separates continuous integration (code compilation & container image pushing) from deployment manifest reconciliation.

```
+-----------------------------------------------------------------------------------------------+
| GITOPS SEPARATION OF CONCERNS                                                                 |
+------------------------------------+----------------------------------------------------------+
| Continuous Integration (CI)        | Compiles source code, runs pytest, builds Docker image,  |
|                                    | pushes immutable image tag/digest to GHCR.               |
+------------------------------------+----------------------------------------------------------+
| Manifest State (GitOps Source)     | Declarative Kustomize manifests in kubernetes/base and   |
|                                    | kubernetes/overlays/primary / dr.                        |
+------------------------------------+----------------------------------------------------------+
| Deployment Controller              | Applies Kustomize overlays to target EKS API server,      |
|                                    | reconciling desired state in Git with actual K8s state.  |
+------------------------------------+----------------------------------------------------------+
```

---

## 2. In-Tree Kustomize Manifest Architecture

Kubernetes manifests are declared using Kustomize native resource overlay blocks:

### A. Base Layer ([`kubernetes/base/kustomization.yaml`](file:///c:/Users/smine/Disaster-Recovery/kubernetes/base/kustomization.yaml))
Defines common resources shared across all environments:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - storage-class.yaml
  - network-policies.yaml
  - app.yaml
  - postgres.yaml
  - ingress.yaml
```

---

### B. Environment Overlays

#### Primary Overlay ([`kubernetes/overlays/primary/kustomization.yaml`](file:///c:/Users/smine/Disaster-Recovery/kubernetes/overlays/primary/kustomization.yaml)):
Labels resources with `environment: primary` and maps `notes-app` to image `ghcr.io/elzabeth-l/vaultrix-eks-notes`.

#### DR Overlay ([`kubernetes/overlays/dr/kustomization.yaml`](file:///c:/Users/smine/Disaster-Recovery/kubernetes/overlays/dr/kustomization.yaml)):
Labels resources with `environment: dr` and applies JSON patches to ingress annotations to disable deletion protection for temporary DR drill environments:
```yaml
patches:
  - target:
      kind: Ingress
      name: notes
    patch: |-
      - op: replace
        path: /metadata/annotations/alb.ingress.kubernetes.io~1load-balancer-attributes
        value: deletion_protection.enabled=false
      - op: remove
        path: /spec/rules/0/host
```

---

## 3. Reconciliation & Drift Prevention

1. **Immutable Image Digests**: Deployments target exact image digests (`digest: sha256:...`) rather than floating tags like `:latest`. This prevents Pods from pulling unexpected code changes on node restarts.
2. **Rollout Gates**: `kubectl -n notes rollout status` blocks deployment execution until all new Pod replicas pass readiness probes (`/readyz`) and complete container launch.
3. **Dry-Run Manifest Validation**: Deployment pipelines execute `kubectl create secret ... --dry-run=client -o yaml | kubectl apply -f -` to safely update secrets without breaking existing connections.
