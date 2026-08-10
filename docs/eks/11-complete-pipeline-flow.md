# 11. Complete End-to-End Pipeline Flow — Technical Notes

## 1. Complete End-to-End Application Lifecycle

The following sequence details the complete path of an application change from developer commit to Kubernetes pod execution and Route 53 DNS publication.

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Developer
    participant GH as GitHub Repository
    participant CI as CI Workflow (eks-app-ci.yml)
    participant CD as Deploy Workflow (eks-app-deploy.yml)
    participant GHCR as GitHub Container Registry
    participant K8s as Primary EKS API Server
    participant LBC as AWS Load Balancer Controller
    participant ALB as AWS Application Load Balancer
    participant R53 as Amazon Route 53
    actor User as User Browser

    Dev->>GH: 1. Push code change to main (applications/eks-app/**)
    GH->>CI: 2. Trigger PR validation (pytest, Docker Buildx ARM64, Kustomize test)
    CI-->>GH: 3. Tests Passed
    Dev->>CD: 4. Dispatch deployment workflow (Primary 2 - EKS application)

    rect rgb(240, 248, 255)
        note over CD, GHCR: Step A: Container Build & Push
        CD->>CD: Execute Docker Buildx compilation (linux/arm64)
        CD->>GHCR: Push ghcr.io/elzabeth-l/vaultrix-eks-notes:${github.sha}
        GHCR-->>CD: Return Image Digest (sha256:a1b2c3...)
    end

    rect rgb(255, 245, 238)
        note over CD, K8s: Step B: Cluster Connect & Secret Setup
        CD->>K8s: aws eks update-kubeconfig --name vaultrix-dr-primary-eks
        CD->>K8s: Helm upgrade --install aws-load-balancer-controller (v3.3.0)
        CD->>K8s: kubectl create secret generic notes-database --from-literal=url=...
    end

    rect rgb(230, 245, 230)
        note over CD, ALB: Step C: Manifest Application & Ingress Rollout
        CD->>CD: Substitute digest in kubernetes/overlays/primary/kustomization.yaml
        CD->>K8s: kubectl apply -k kubernetes/overlays/primary
        K8s->>K8s: Rollout statefulset/postgres & deployment/notes
        LBC->>ALB: Create/Update ALB listeners, target groups (target type: ip)
        LBC->>K8s: Update Ingress notes status with ALB Hostname
    end

    rect rgb(255, 250, 205)
        note over CD, User: Step D: Health Verification & DNS Publication
        CD->>ALB: Probe http://<ALB>/healthz with Host: eks.dr.vaultrix.in
        ALB-->>CD: HTTP 200 OK
        CD->>R53: Upsert CNAME eks.dr.vaultrix.in -> ALB Hostname
        R53-->>CD: Record Set Changed
        User->>R53: Query eks.dr.vaultrix.in
        R53-->>User: ALB Hostname
        User->>ALB: HTTP GET / (User sees updated application!)
    end
```
