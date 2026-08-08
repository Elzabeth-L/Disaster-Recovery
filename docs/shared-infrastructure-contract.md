# Shared Infrastructure Contract

Contract version: `1.0.0` (frozen 2026-08-08)

## Contract principles

Shared roots create resources once and expose stable, non-secret identifiers. Application roots read outputs; they do not call shared networking modules, import shared resources, retag them, or manage their lifecycle. Output removal/rename is a breaking API change requiring both owners' review and a migration release note.

## State boundaries

| State key | Owner | Resources |
|---|---|---|
| `bootstrap/terraform.tfstate` | Platform | Backend bucket and backend security; initially local then migrated |
| `global/shared/terraform.tfstate` | Platform | Route 53 hosted zone, GitHub OIDC provider/roles or their foundation, account-level shared policy |
| `primary/shared/terraform.tfstate` | Platform | Mumbai VPC, subnets, routes, IGW, endpoint, shared tags |
| `primary/eks/terraform.tfstate` | EKS owner | Primary EKS and EKS-owned AWS resources |
| `primary/ec2/terraform.tfstate` | collaborator | Primary EC2/RDS/AWS Backup app resources |
| `dr/shared/terraform.tfstate` | Platform | Singapore pilot-light network and regional backup foundations |
| `dr/eks/terraform.tfstate` | EKS owner | On-demand DR EKS resources |
| `dr/ec2/terraform.tfstate` | collaborator | On-demand DR EC2/RDS resources |

`global/shared` avoids making either Region the owner of global/account resources. All state objects reside under separately authorized prefixes in the approved backend bucket.

## Regional shared outputs

Each regional shared root exposes region-local names; consumers select the matching state rather than ambiguous combined outputs.

| Output | Type | Meaning/consumer rule |
|---|---|---|
| `contract_version` | `string` | Semantic contract version, initially `1.0.0` |
| `environment` | `string` | `primary` or `dr` |
| `aws_region` | `string` | Region of every resource in this state |
| `vpc_id` | `string` | Existing VPC; consumers never manage it |
| `vpc_cidr_block` | `string` | Validation/security rule input only |
| `availability_zone_ids` | `list(string)` | Stable AZ IDs in subnet order |
| `public_subnet_ids` | `list(string)` | ALBs/NAT only; order matches AZ IDs |
| `ec2_private_subnet_ids` | `list(string)` | EC2 application compute |
| `eks_private_subnet_ids` | `list(string)` | EKS nodes/control-plane networking |
| `database_subnet_ids` | `list(string)` | RDS subnet group inputs |
| `private_route_table_ids` | `map(list(string))` | Keys `ec2`, `eks`, `database`; endpoint/egress diagnostics |
| `s3_gateway_endpoint_id` | `string` | Existing endpoint; consumers do not associate new shared routes |
| `name_prefix` | `string` | Approved naming prefix |
| `common_tags` | `map(string)` | Required base tags; consumer overlays Application/Owner/Expiration |

Subnet lists must be deterministically ordered by AZ ID. Changing list order without changing resources is prohibited because it can force replacements in consumers.

## Global shared outputs

| Output | Type | Meaning |
|---|---|---|
| `contract_version` | `string` | Global contract version |
| `route53_zone_id` | `string` | Existing `dr.vaultrix.in` public zone |
| `route53_zone_name` | `string` | `dr.vaultrix.in` |
| `route53_name_servers` | `list(string)` | Values copied manually to GoDaddy after approval |
| `github_shared_role_arn` | `string` | Shared pipeline role, if global root owns it |
| `github_eks_role_arn` | `string` | EKS pipeline role |
| `github_ec2_role_arn` | `string` | EC2 pipeline role |
| `primary_region` | `string` | `ap-south-1` |
| `dr_region` | `string` | `ap-southeast-1` |

## Consumer pattern (illustrative, not implemented)

```hcl
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket       = var.state_bucket
    key          = "primary/shared/terraform.tfstate"
    region       = var.state_region
    use_lockfile = true
  }
}

locals {
  vpc_id              = data.terraform_remote_state.shared.outputs.vpc_id
  ec2_subnet_ids      = data.terraform_remote_state.shared.outputs.ec2_private_subnet_ids
  database_subnet_ids = data.terraform_remote_state.shared.outputs.database_subnet_ids
}
```

Backend bucket/key values are partial backend/config inputs, not secrets committed to reusable modules. Reading remote state requires access to the whole object, so EC2 roles receive only the exact shared/global state object reads they need.

## Ownership enforcement

- Resource policies, IAM paths, tags, and CI path filters reinforce ownership; Terraform state remains the source of lifecycle ownership.
- Application stacks may create their own security groups and rules. They may not add rules to a shared security group.
- EKS creates only `eks.dr.vaultrix.in` and diagnostic EKS records. EC2 creates only `ec2.dr.vaultrix.in` and diagnostic EC2 records.
- Changes to subnet IDs, hosted-zone identity, regions, or state keys require a coordinated migration and major contract version.

## Contract changelog

### 1.0.0 - 2026-08-08

- Froze the regional and global output names and types documented above.
- Confirmed `primary/ec2` may read only `primary/shared` and `global/shared` and writes only its own state object and lockfile.
- Added a zero-resource EC2 consumer root and path-aware pull-request validation.
- Declared output removal, rename, type change, state-key change, or subnet reordering a breaking change requiring both owners' review.
