# 03. Application Deployment & Kustomize Workflow — Technical Notes

## 1. Overview & Repository Layout

The EKS application is a Notes Management service (`applications/eks-app`). Kubernetes deployment manifests are defined under `kubernetes/` using Kustomize:

```
kubernetes/
├── README.md
├── base/
│   ├── app.yaml              # ServiceAccount, Service, PodDisruptionBudget, Deployment
│   ├── postgres.yaml         # Headless Service & StatefulSet for PostgreSQL
│   ├── ingress.yaml          # Ingress resource targeting AWS Load Balancer Controller
│   ├── namespace.yaml        # Namespace definition (notes)
│   ├── network-policies.yaml # NetworkPolicy rules restricting pod ingress/egress
│   ├── storage-class.yaml    # Encrypted gp3 StorageClass
│   └── kustomization.yaml    # Base kustomization declaration
└── overlays/
    ├── primary/
    │   └── kustomization.yaml# Primary overlay (Image: ghcr.io/elzabeth-l/vaultrix-eks-notes)
    └── dr/
        └── kustomization.yaml# DR overlay (Patches Ingress annotations for Singapore)
```

---

## 2. Kustomize Image Tag Substitution Mechanics

In the base deployment manifest `kubernetes/base/app.yaml`, the image placeholder is set to:
`image: notes-app:replace-me`

During continuous deployment ([`.github/workflows/eks-app-deploy.yml`](file:///c:/Users/smine/Disaster-Recovery/.github/workflows/eks-app-deploy.yml)), the deployment script dynamically replaces `replace-me` with the immutable container digest (`sha256:...`) produced by Docker Buildx:

```bash
digest="${{ needs.build.outputs.digest }}"
sed -i "s|newTag: replace-me|digest: ${digest}|" kubernetes/overlays/primary/kustomization.yaml
kubectl apply -k kubernetes/overlays/primary
```

### Primary Overlay Result (`kubernetes/overlays/primary/kustomization.yaml`):
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
commonLabels:
  app.kubernetes.io/part-of: vaultrix-dr
  environment: primary
images:
  - name: notes-app
    newName: ghcr.io/elzabeth-l/vaultrix-eks-notes
    digest: sha256:a1b2c3d4...
```

---

## 3. Rollout & Verification Flow

Once `kubectl apply -k` is executed, the deployment step enforces strict health verification before proceeding:

1. **StatefulSet Rollout Status**:
   `kubectl -n notes rollout status statefulset/postgres --timeout=10m`
2. **Deployment Rollout Status**:
   `kubectl -n notes rollout status deployment/notes --timeout=10m`
3. **Ingress Load Balancer Hostname Verification**:
   Polls `kubectl -n notes get ingress notes` until the AWS Load Balancer Controller populates the ALB DNS hostname (`status.loadBalancer.ingress[0].hostname`).
4. **Health Check Probing**:
   Executes `curl --fail -H 'Host: eks.dr.vaultrix.in' http://<ALB_DNS>/healthz`.
5. **Route 53 CNAME Update**:
   Updates Route 53 CNAME record `eks.dr.vaultrix.in` to point to the verified ALB DNS hostname.
