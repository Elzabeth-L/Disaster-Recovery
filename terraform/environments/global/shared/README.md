# Global Shared DNS and GitHub OIDC/IAM

Combined Phases 4-5 owns the `dr.vaultrix.in` public hosted zone and repository-scoped GitHub Actions IAM roles. It references the account's existing GitHub OIDC provider as read-only because another Terraform state already owns that account-level provider.

## Security boundaries

- Plan roles trust only this repository's `pull_request` or protected `main` subjects.
- Apply roles trust only the exact `shared-apply`, `eks-apply`, or `ec2-apply` GitHub Environment subject.
- Each role can read only the shared and owner-specific state objects it needs.
- Plan roles can manage only their state lockfiles; they cannot write Terraform state.
- Apply roles can write only their ownership scope and are explicitly denied cross-owner state writes.
- EKS and EC2 apply roles can change only their approved DNS names and record types.
- Workload mutation permissions are intentionally added in the owning implementation phase after the exact resource plan exists; these foundation roles do not carry broad administrator permissions.

The hosted zone uses `prevent_destroy`; removing it requires a deliberate code change and separate approval. No application DNS record is created before a healthy endpoint exists.

## Local workflow

```powershell
Copy-Item backend.hcl.example backend.hcl
Copy-Item terraform.tfvars.example terraform.tfvars
# Replace the account ID, backend bucket, and owner placeholders.
terraform init -backend-config=backend.hcl
terraform fmt -check
terraform validate
terraform plan -out phase-4-5.tfplan
```

Backend configuration, variable values, plans, state, and credentials remain ignored. GitHub Environments and repository role-ARN variables are configured after apply. GoDaddy delegation is a manual action using the four name servers emitted by Terraform.
