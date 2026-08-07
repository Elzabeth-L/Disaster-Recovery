# Phase 2 Plan - Primary Shared Network

Status: Terraform code and speculative plan complete; no Phase 2 AWS resources created. Date: 2026-08-07.

## Decision

Use one replaceable Amazon Linux 2023 `t4g.nano` NAT instance as the cost-first primary egress path. Keep `nat_gateway` as an explicit managed fallback and `none` for periods when general private egress is unnecessary. The NAT instance is intentionally single-AZ and is not presented as a production high-availability design.

Official/live Mumbai pricing used on 2026-08-07:

- `t4g.nano`: `$0.0028/hour`.
- Public IPv4: `$0.005/hour`.
- gp3: `$0.0912/GB-month`; the planned 8 GiB volume is about `$0.73/month`.
- Zonal NAT Gateway: `$0.056/hour` plus `$0.056/GB` processed and one billed public IPv4 address.
- S3 gateway endpoint: no additional endpoint hourly or processing charge.

At 730 hours, the NAT-instance base is approximately `$6.42/month` before transfer or CPU-credit effects. A single zonal NAT Gateway base is approximately `$44.53/month` before its per-GB processing and transfer charges. The cost-first choice saves about `$38.10/month` at continuous runtime, with lower availability, throughput, and operational simplicity.

Sources: [Amazon VPC pricing](https://aws.amazon.com/vpc/pricing/), [EC2 On-Demand pricing](https://aws.amazon.com/ec2/pricing/on-demand/), [AWS NAT instance guidance](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_NAT_Instance.html), and [S3 gateway endpoint guidance](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html). Exact regional rates were resolved through the AWS Price List API where the company trust path allowed it.

## Live planning checks

- Caller: explicitly approved AWS account root for account `598120810297`; credentials were kept in process memory.
- Available standard Mumbai AZs: `aps1-az1`, `aps1-az2`, and `aps1-az3`.
- Selected deterministic AZ IDs: `aps1-az1` and `aps1-az2`.
- `t4g.nano` is offered in all three available AZs.
- AL2023 ARM64 is resolved at plan time through the AWS public SSM parameter rather than pinned to a stale AMI.
- Existing VPC CIDRs are `10.30.0.0/16` and `172.31.0.0/16`; planned `10.10.0.0/16` does not overlap.

## Saved plan summary

`41 to add, 0 to change, 0 to destroy`:

- One VPC and one Internet Gateway.
- Eight subnets across two AZs.
- Eight route tables and eight explicit subnet associations.
- Two public Internet routes.
- One S3 gateway endpoint associated with all six private route tables.
- One NAT security group, four private-CIDR ingress rules, and one outbound rule.
- One AL2023 `t4g.nano` NAT instance with encrypted 8 GiB gp3 storage and one Elastic IP.
- Four EC2/EKS private default routes through the NAT instance.

No database route table has an Internet default route. Only the two public subnets map public IPs. No ingress rule permits `0.0.0.0/0`. The NAT instance has no SSH key or inbound administration port, requires IMDSv2, disables source/destination checking, uses standard CPU credits, and forwards only the four EC2/EKS private CIDRs.

## Contract outputs

The root exposes contract version `1.0.0`, environment, Region, VPC ID/CIDR, deterministically ordered AZ IDs and subnet IDs, route-table IDs grouped as `ec2`, `eks`, and `database`, the S3 endpoint ID, naming prefix, common tags, egress mode, and NAT public IP.

## Validation

- `terraform fmt -check -recursive`: passed.
- `terraform init` with S3 native locking: passed.
- `terraform validate`: passed without warnings after correction.
- Root-authenticated speculative plan: passed.
- Plan-JSON assertions: 41 create-only changes, zero destructive changes, zero database default routes, zero public ingress rules, two public subnets, zero private subnets assigning public IPs, IMDSv2 required, encrypted NAT root storage, and source/destination checking disabled.
- TFLint, Checkov, and tfsec: not installed on the restricted company laptop.
- Provider lockfile: Windows-only checksum limitation remains because the company network blocks HashiCorp's official cross-platform checksum path.

## Required tests after an approved apply

Phase 2 is not accepted until a short-lived private test instance proves S3 endpoint routing and general NAT egress, the NAT instance survives reboot with forwarding rules restored, database route tables remain isolated, and cleanup removes every temporary test resource. EKS-specific node/image/controller tests occur before accepting NAT-instance egress for Phase 7A.

## Gate

Do not apply the saved plan. First obtain Gokul's required CODEOWNER approval and merge the Phase 2 planning PR. Recreate a fresh plan from protected `main`, compare it with this report, and request the separate instruction `Approved. Apply Phase 2.`
