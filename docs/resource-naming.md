# Resource Naming and Tags

## Standard

Use `vaultrix-dr-<environment>-<application>-<component>` where length permits. This is slightly more explicit than the prompt's pattern and avoids ambiguous `vaultrix-dr-dr-vpc`.

Examples:

- `vaultrix-dr-primary-shared-vpc`
- `vaultrix-dr-primary-eks-cluster`
- `vaultrix-dr-primary-ec2-alb`
- `vaultrix-dr-primary-ec2-rds`
- `vaultrix-dr-dr-shared-vpc`
- `vaultrix-dr-dr-eks-cluster`

Globally unique services append account/Region or a deterministic suffix: `vaultrix-dr-<account-id>-tfstate` and `vaultrix-dr-primary-eks-backup-<suffix>`. Never use random names where a stable name is sufficient. DNS names remain `eks.dr.vaultrix.in` and `ec2.dr.vaultrix.in`.

## Required tags

| Key | Values/rule |
|---|---|
| `Project` | `vaultrix-dr` |
| `Environment` | `primary`, `dr`, `global`, or `bootstrap` |
| `Application` | `shared`, `eks`, or `ec2` |
| `ManagedBy` | `terraform` |
| `Owner` | Approved team identifier, not an invented username |
| `CostCenter` | Approved project/lab value |
| `Expiration` | ISO-8601 date/time for temporary drill resources; `persistent` only when intended |
| `DataClassification` | `public`, `internal`, or `confidential` as applicable |

Controller-generated resources must receive equivalent tags through supported controller settings. AWS-mandated discovery tags are additions, not replacements. Tag policy exceptions (some generated/unsupported resources) are documented.

## Constraints

Lowercase and hyphens are the default; service-specific character/length rules win. IAM roles state function (`github-eks-plan`, `github-eks-apply`) and do not imply administrator access. Backup names include workload and policy, while state keys use the stable paths in the shared contract.

