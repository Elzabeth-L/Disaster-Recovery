# 13. GitHub Actions Workflows — Comprehensive Notes

## Overview

The repository utilizes five primary GitHub Actions workflow files located in `.github/workflows/`. These workflows automate container image compilation, infrastructure provisioning, pull request validation, temporary DR environment deployment, and interactive DR drills.

```
+-----------------------------------------------------------------------------------------------+
| GITHUB ACTIONS WORKFLOW SUITE MATRIX                                                          |
+--------------------------+---------------------+---------------------+------------------------+
| Workflow File            | Workflow Name       | Trigger Conditions  | Scope / Purpose        |
+--------------------------+---------------------+---------------------+------------------------+
| ec2-app-build.yml        | Primary 4 - EC2 app | Push main / PR      | Docker build, GHCR push|
|                          |                     | applications/ec2-app| & SSM remote deploy    |
+--------------------------+---------------------+---------------------+------------------------+
| ec2-platform.yml         | Primary 3 - EC2 infra| workflow_dispatch   | Terraform Plan & Apply |
|                          |                     | (Plan / Apply)      | for primary/ec2 root   |
+--------------------------+---------------------+---------------------+------------------------+
| dr-platform.yml          | DR 1 - Infrastructure| workflow_dispatch  | Terraform Plan & Apply |
|                          |                     | (shared/eks/ec2)    | for dr/* roots         |
+--------------------------+---------------------+---------------------+------------------------+
| dr-drill.yml             | DR 2 - Drill        | workflow_dispatch   | Interactive DR drill & |
|                          |                     | (Deploy/Cutover/...) | automated failover     |
+--------------------------+---------------------+---------------------+------------------------+
| terraform-pr.yml         | Terraform PR Checks | Pull Requests on    | Format, linting & plan |
|                          |                     | terraform/**        | validation across roots|
+--------------------------+---------------------+---------------------+------------------------+
```

---

## 1. Deep Dive: `ec2-app-build.yml` (Application CI/CD Pipeline)

- **File Location**: `.github/workflows/ec2-app-build.yml`
- **Purpose**: Compiles the Python Flask application into an immutable Docker image, publishes it to GitHub Container Registry (GHCR), and triggers a remote service restart on the active EC2 instance.

### Workflow Configuration:
```yaml
name: Primary 4 - EC2 application

on:
  push:
    branches: [main]
    paths:
      - 'applications/ec2-app/**'
      - '.github/workflows/ec2-app-build.yml'
  pull_request:
    branches: [main]
    paths:
      - 'applications/ec2-app/**'
      - '.github/workflows/ec2-app-build.yml'
  workflow_dispatch:

permissions:
  contents: read
  packages: write
```

### Job Breakdown:
1. `build-and-push`:
   - Runs `docker/setup-buildx-action@v3` and `docker/login-action@v3` for `ghcr.io`.
   - Tags image with commit SHA (`ghcr.io/elzabeth-l/vaultrix-ec2-app:${{ github.sha }}`) and `:latest`.
   - Pushes tags to GHCR on `main` branch merges.
2. `deploy-to-ec2`:
   - Runs under environment `ec2-apply`.
   - Uses OpenID Connect (`id-token: write`) to assume IAM role `vars.AWS_EC2_APPLY_ROLE_ARN` in `ap-south-1`.
   - Finds EC2 instance tagged `Name=vaultrix-dr-primary-ec2-instance`.
   - Issues SSM command: `aws ssm send-command --instance-ids "$instance_id" --document-name AWS-RunShellScript --parameters 'commands=["systemctl restart vaultrix-app.service"]'`.
   - Waits for execution via `aws ssm wait command-executed`.

---

## 2. Deep Dive: `ec2-platform.yml` (Primary Infrastructure Workflow)

- **File Location**: `.github/workflows/ec2-platform.yml`
- **Purpose**: Manages automated planning and execution of Terraform for the primary EC2 workload root (`terraform/environments/primary/ec2`).

### Workflow Configuration:
```yaml
name: Primary 3 - EC2 infrastructure

on:
  workflow_dispatch:
    inputs:
      operation:
        description: Plan is read-only; Apply creates or updates the cost-bearing primary platform
        required: true
        type: choice
        options: [Plan, Apply]
```

### Job Breakdown:
1. `plan`:
   - Assumes AWS OIDC role `vars.AWS_EC2_PLAN_ROLE_ARN` in `ap-south-1`.
   - Runs `terraform init` with backend S3 bucket `vaultrix-dr-598120810297-tfstate` and key `primary/ec2/terraform.tfstate`.
   - Runs `terraform plan -lock=false -out=phase7b.tfplan -var="expected_aws_account_id=598120810297" -var="state_bucket=vaultrix-dr-598120810297-tfstate" -var="cost_acknowledgement=APPROVE_PRIMARY_EC2_COSTS"`.
   - Uploads binary plan `phase7b.tfplan` and text plan `phase7b-plan.txt` as GitHub Actions build artifacts.
2. `apply`:
   - Environment: `ec2-apply` (requires human approval gate).
   - Assumes AWS OIDC role `vars.AWS_EC2_APPLY_ROLE_ARN`.
   - Downloads artifact `phase7b.tfplan`.
   - Executes `terraform apply -auto-approve phase7b.tfplan`.

---

## 3. Deep Dive: `dr-platform.yml` (DR Infrastructure Workflow)

- **File Location**: `.github/workflows/dr-platform.yml`
- **Purpose**: Provisions or cleans up temporary DR infrastructure components (`shared-egress`, `eks`, `ec2`) in `ap-southeast-1`.

### Workflow Configuration:
```yaml
name: DR 1 - Infrastructure

on:
  workflow_dispatch:
    inputs:
      component:
        description: Temporary DR component
        required: true
        type: choice
        options: [shared-egress, eks, ec2]
      operation:
        description: Plan is read-only; Apply uses the exact saved plan
        required: true
        type: choice
        options: [Plan deploy, Apply deploy, Plan cleanup, Apply cleanup]
```

### Operations Matrix:
- Component `ec2` targets directory `terraform/environments/dr/ec2` with backend key `dr/ec2/terraform.tfstate` in `ap-southeast-1`.
- Sets Terraform variable `cost_acknowledgement=APPROVE_DR_DRILL_COSTS`.
- `Apply cleanup` passes `-destroy` flag to Terraform plan, tearing down temporary DR compute resources.

---

## 4. Deep Dive: `dr-drill.yml` (Interactive Disaster Recovery Drill)

- **File Location**: `.github/workflows/dr-drill.yml`
- **Purpose**: Executes automated DR exercises including task snapshot seeding, simulated primary instance failure, Route 53 health-check failover validation, failback, and cleanup.

### Workflow Configuration:
```yaml
name: DR 2 - Drill

on:
  workflow_dispatch:
    inputs:
      operation:
        description: Application preparation, traffic cutover, or application cleanup
        required: true
        type: choice
        options:
          - Deploy or refresh DR applications
          - Failover to DR
          - Failback to primary
          - Remove DR applications
      confirmation:
        description: Use DEMONSTRATE_DR for failover/failback or CLEANUP_DR_APPS for removal
        required: false
        type: string
```

### Operational Steps Deep-Dive:

#### Operation A: `Deploy or refresh DR applications` (`deploy-ec2`)
1. Fetches primary tasks snapshot via `curl http://ec2.dr.vaultrix.in/api/tasks -o tasks.json`.
2. Assumes DR OIDC role in `ap-southeast-1`.
3. Verifies DR ALB DNS endpoint `/health`.
4. Polls `/api/status` until `database == "connected"`.
5. Clears existing DR tasks via `DELETE /api/tasks/<id>`.
6. Seeds primary tasks snapshot via `POST /api/tasks`.

#### Operation B: `Failover to DR` (`cutover-ec2`)
1. Validates `confirmation == 'DEMONSTRATE_DR'`.
2. Probes diagnostic endpoint `http://ec2-dr.dr.vaultrix.in/api/status` to confirm DR app and DB status.
3. Assumes Primary AWS OIDC role in `ap-south-1`.
4. Stops Primary EC2 instance: `aws ec2 stop-instances --instance-ids "$instance_id"`.
5. Waits for status `instance-stopped`.
6. Polls public FQDN `http://ec2.dr.vaultrix.in/api/status` until response returns `environment == "DR"`.

#### Operation C: `Failback to primary` (`cutover-ec2`)
1. Starts Primary EC2 instance: `aws ec2 start-instances --instance-ids "$instance_id"`.
2. Waits for status `instance-status-ok`.
3. Polls public FQDN `http://ec2.dr.vaultrix.in/api/status` until response returns `environment == "PRIMARY"`.

#### Operation D: `Remove DR applications` (`cleanup-eks` / `cleanup-ec2`)
Requires `confirmation == 'CLEANUP_DR_APPS'`. Deletes temporary DR workloads and Route 53 diagnostic CNAME records.

---

## 5. Deep Dive: `terraform-pr.yml` (PR Validation Workflow)

- **File Location**: `.github/workflows/terraform-pr.yml`
- **Purpose**: Runs automated linting, formatting checks (`terraform fmt -check`), and spec plans on every pull request targeting `main`.

### Workflow Steps:
1. Runs Python matrix generator `python3 .github/scripts/terraform_matrix.py` to identify changed Terraform environments.
2. Executes `terraform init` and `terraform validate` across modified environment roots.
3. Generates read-only speculative plan (`terraform plan -lock=false`) and posts the plan diff summary directly into the Pull Request review comments.
