# Networking

## Regional topology

The baseline retains the requested eight `/24` subnets in each `/16` VPC. CIDRs do not overlap and leave ample room. AZs will be selected dynamically from available standard AZs; letter names are not assumed to map physically between accounts or Regions.

| Function | Primary AZ 1 / AZ 2 | DR AZ 1 / AZ 2 | Route intent |
|---|---|---|---|
| Public | `10.10.1.0/24`, `10.10.2.0/24` | `10.20.1.0/24`, `10.20.2.0/24` | Internet Gateway; ALBs and NAT if approved |
| EC2 private | `10.10.11.0/24`, `10.10.12.0/24` | `10.20.11.0/24`, `10.20.12.0/24` | No direct IGW; approved egress path only |
| EKS private | `10.10.21.0/24`, `10.10.22.0/24` | `10.20.21.0/24`, `10.20.22.0/24` | No direct IGW; approved egress path only |
| Database | `10.10.31.0/24`, `10.10.32.0/24` | `10.20.31.0/24`, `10.20.32.0/24` | No default Internet route |

RDS subnet groups use both database subnets even when the lab DB instance is Single-AZ. EBS is AZ-scoped and has no subnet placement.

## Routing

- Each VPC has one Internet Gateway; public route tables use it.
- Private workload route tables must not point directly to an IGW.
- Database route tables have no Internet default route.
- An S3 gateway endpoint is associated with EC2, EKS, and database route tables only where S3 access is required. Endpoint and bucket policies restrict approved buckets/actions.
- No VPC peering is required for backup-and-restore. Cross-Region recovery data moves through supported AWS copy/replication mechanisms.

## Egress decision

The S3 gateway endpoint is free and suitable for S3, but it cannot provide ECR, STS, EC2, package repository, chart registry, or public image access. Choose before Phase 7A:

| Option | Cost | Security/operations | Recommendation |
|---|---|---|---|
| One small NAT instance | About $8.47/month base in Mumbai for Free Tier-eligible `t4g.micro`, one public IPv4, and 8 GiB gp3 when not covered by Free Tier/credits | Private nodes; self-managed, limited, single-AZ | Approved cost-first lab direction |
| One zonal NAT Gateway in primary while EKS runs | About $44.53/month base plus $0.056/GB processing in Mumbai | Private nodes, managed and simpler | Fallback if NAT instance is unreliable |
| Interface endpoints | Hourly per endpoint/AZ plus data | Private, granular; many endpoints | Use only after measuring required set |
| Public nodes with public IPs | Per-node public IPv4 | Larger exposure and diverges from target | Emergency short-lived lab fallback only |

The selected lab direction is a replaceable Amazon Linux 2023 NAT instance, not AWS's obsolete NAT AMI. It has no inbound administration ports, uses a tightly scoped forwarding security group, and is monitored/rebuilt rather than repaired manually. The Terraform input also supports `nat_gateway` and `none`; either change requires a new reviewed plan. If testing shows node registration, image pulls, controller calls, or recovery time are unreliable, replace it with one managed zonal NAT Gateway. AWS now also offers regional NAT Gateways that expand across active AZs, but per-AZ hourly/public-address billing makes that option inappropriate for this cost-first lab. Interface endpoints are not the default because private EKS can require ECR API/Docker, EC2, STS or EKS Auth, ELB, Logs, and other endpoints, each billed per endpoint AZ.

DR has no NAT until a drill. The DR workflow creates the approved egress option, uses it for provisioning/restore, then removes it during cleanup.

## Security and Kubernetes discovery

- Public ALBs accept only application ports. No SSH from `0.0.0.0/0`.
- EC2 ingress is from its ALB security group; RDS ingress is only from the EC2 application security group.
- EKS cluster/node security follows EKS minimum rules; PostgreSQL is cluster-internal only.
- Subnet tags needed by the AWS Load Balancer Controller are owned by shared networking and are part of the contract.
- VPC Flow Logs are optional in the lab because CloudWatch Logs/S3 ingestion and storage cost money; enable them temporarily during security validation or production upgrade.

## Validation

Before consumers start: verify CIDR non-overlap, two distinct AZ IDs, route-table associations, no IGW route on database subnets, S3 access through the endpoint, ALB subnet tagging, and Network ACL defaults. During an AZ drill, prove that an AZ-1 EBS volume is not directly attachable in AZ-2 and exercise snapshot/pgBackRest recovery.
