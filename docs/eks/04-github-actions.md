# 04. GitHub Actions Workflows — Technical Notes

## 1. Overview

The repository contains four dedicated GitHub Actions workflow files managing EKS application integration, deployment, platform provisioning, and DR drills:

```
+-----------------------------------------------------------------------------------------------+
| EKS WORKFLOW SUITE                                                                            |
+--------------------------+---------------------+---------------------+------------------------+
| Workflow File            | Name                | Triggers            | Purpose / Scope        |
+--------------------------+---------------------+---------------------+------------------------+
| eks-app-ci.yml           | CI - EKS application| PR on main          | Pytest, Docker ARM64   |
|                          |                     | (applications/eks-app) build & Kustomize test |
+--------------------------+---------------------+---------------------+------------------------+
| eks-app-deploy.yml       | Primary 2 - EKS app | workflow_dispatch   | Build & push to GHCR,  |
|                          |                     |                     | Helm LBC & K8s deploy  |
+--------------------------+---------------------+---------------------+------------------------+
| eks-platform.yml         | Primary 1 - EKS platform| workflow_dispatch| Terraform Plan/Apply   |
|                          |                     | (Plan / Apply)      | for primary EKS root   |
+--------------------------+---------------------+---------------------+------------------------+
| dr-platform.yml          | DR 1 - Infrastructure| workflow_dispatch  | Terraform Plan/Apply   |
|                          |                     | (shared/eks/ec2)    | for DR EKS in Singapore|
+--------------------------+---------------------+---------------------+------------------------+
```

---

## 2. Deep Dive: `eks-app-ci.yml` (Pull Request Validation)

- **File Location**: [`.github/workflows/eks-app-ci.yml`](file:///c:/Users/smine/Disaster-Recovery/.github/workflows/eks-app-ci.yml)
- **Triggers**: Pull requests targeting `main` modifying `applications/eks-app/**` or `kubernetes/**`.

### Key Steps:
1. Sets up Python 3.13 and installs test dependencies from `applications/eks-app/requirements-dev.txt`.
2. Runs unit tests using `pytest` inside `applications/eks-app/`.
3. Sets up Docker Buildx and validates non-push compilation for `linux/arm64` platform.
4. Uses `kubectl kustomize kubernetes/overlays/primary` to render the combined manifest string into `${RUNNER_TEMP}/primary.yaml`.
5. Verifies image tag substitution: Fails the build if `replace-me` is left unrendered in `primary.yaml`.

---

## 3. Deep Dive: `eks-app-deploy.yml` (Primary Deployment Pipeline)

- **File Location**: [`.github/workflows/eks-app-deploy.yml`](file:///c:/Users/smine/Disaster-Recovery/.github/workflows/eks-app-deploy.yml)
- **Triggers**: Manual `workflow_dispatch`.

### Job 1: `build`
- Logs into `ghcr.io` using `GITHUB_TOKEN`.
- Builds multi-stage ARM64 container image (`linux/arm64`).
- Pushes image tag `ghcr.io/elzabeth-l/vaultrix-eks-notes:${{ github.sha }}`.
- Outputs image digest `steps.build.outputs.digest` (`sha256:...`).

### Job 2: `deploy`
- Environment: `eks-apply` (requires human approval gate).
- Assumes AWS OIDC IAM role `vars.AWS_EKS_APPLY_ROLE_ARN` in `ap-south-1`.
- Updates kubeconfig via `aws eks update-kubeconfig --name vaultrix-dr-primary-eks --region ap-south-1`.
- Installs AWS Load Balancer Controller version `3.3.0` in `kube-system` via Helm.
- Generates/retrieves database credentials from AWS Secrets Manager secret `vaultrix-dr-primary-eks/notes/database`.
- Creates Kubernetes Secret `notes-database` in namespace `notes`.
- Updates `kubernetes/overlays/primary/kustomization.yaml` substituting `digest: <sha256>`.
- Applies manifests: `kubectl apply -k kubernetes/overlays/primary`.
- Waits for rollout completion (`statefulset/postgres` and `deployment/notes`).
- Obtains ALB hostname from Ingress, probes `http://<ALB>/healthz` with `Host: eks.dr.vaultrix.in`, and upserts Route 53 CNAME record `eks.dr.vaultrix.in`.
