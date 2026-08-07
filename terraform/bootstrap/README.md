# Terraform Backend Bootstrap

Phase 1 created one S3 bucket for all independently authorized Terraform state prefixes. It does not use a DynamoDB table: Terraform uses S3 native lockfiles through `use_lockfile = true`.

## Deployed resources

- S3 bucket named `vaultrix-dr-<account-id>-tfstate`
- Bucket ownership enforced
- All four S3 Block Public Access settings
- Versioning
- SSE-S3 (`AES256`) default encryption
- TLS-only bucket policy
- Lifecycle expiration for noncurrent versions after 90 days by default
- Seven-day cleanup of incomplete multipart uploads

The bucket has `prevent_destroy = true`. Removing it requires an explicit, reviewed recovery/cleanup procedure.

## Two-stage bootstrap runbook

The initial apply and state migration were completed on 2026-08-07. The steps below are retained as the recovery/rebuild runbook.

The first apply must use local state because the remote bucket does not exist yet:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
# Replace the account ID and owner values.
terraform init
terraform fmt -check
terraform validate
terraform plan -out bootstrap.tfplan
terraform apply bootstrap.tfplan
```

No future apply is authorized merely by these instructions. Review the plan and receive explicit approval first.

After the bucket exists:

1. Copy and protect the local `terraform.tfstate` as migration evidence.
2. Copy `backend.tf.example` to `backend.tf`.
3. Copy `backend.hcl.example` to ignored `backend.hcl` and replace the account ID.
4. Run `terraform init -migrate-state -backend-config=backend.hcl`.
5. Verify the `bootstrap/terraform.tfstate` object and a `.tflock` during a locking test.
6. Remove the local state only after its remote version and recovery process are verified.

## Required identity

The owner explicitly approved the locally authenticated AWS account root identity as a one-time Phase 1 bootstrap exception. Root use ended after apply, live verification, and state migration. Phase 2 and later work must use an authenticated individual AWS role or IAM Identity Center permission set; automated workflows must use GitHub OIDC. The configuration requires the expected 12-digit account ID and restricts the AWS provider to that account. Later GitHub OIDC roles receive access only to their state object prefixes and lockfiles.

## Validation limitations on the current laptop

The project pin is Terraform 1.15.8 and AWS provider 6.54.0. The current laptop has Terraform 1.12.2; it can format and validate compatible syntax, but CI and implementation should use the pinned version. TFLint and Checkov are not currently installed. Provider 6.55.0 appeared in a documentation index but was rejected by the live Terraform Registry; initialization resolved 6.54.0 as the newest available 6.x release, so it is pinned exactly.

The company network allowed installation through its configured provider path but returned HTTP 403 when Terraform attempted to download official Windows/Linux checksums. The current dependency lock file is Windows-only and must be regenerated with official `windows_amd64` and `linux_amd64` checksums before Linux CI is made required.
