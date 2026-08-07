# Phase 3 DR Shared Network Plan

Status: planning and validation complete; no Phase 3 infrastructure has been applied.

## Scope

Phase 3 adds a Singapore (`ap-southeast-1`) regional shared root for the pilot-light network. It reuses the regional-network module and owns only:

- one `10.20.0.0/16` VPC with DNS support and hostnames;
- one Internet Gateway;
- two public, two EC2-private, two EKS-private, and two database `/24` subnets;
- eight dedicated route tables and associations;
- Internet default routes on the two public route tables only; and
- one S3 gateway endpoint associated with all six private route tables.

The root fixes `egress_mode = "none"`. It cannot create a NAT instance, NAT Gateway, Elastic IP, compute, security group, RDS, EKS, ALB, DNS, or IAM resource. A future recovery workflow may add approved temporary egress and must remove it during cleanup.

## Live preflight

Read-only checks on 2026-08-07 confirmed account `598120810297` and three available standard Singapore AZs. Deterministic selection uses `apse1-az1` and `apse1-az2`. The only existing Singapore VPC was the default `172.31.0.0/16`, so planned `10.20.0.0/16` does not overlap.

The company TLS proxy certificate was not available to the AWS CLI for the Singapore EC2 endpoint. The two metadata-only checks used short-lived credentials in process memory and `--no-verify-ssl`; credentials were cleared immediately. Terraform backend/provider operations retained normal TLS verification and succeeded.

## Validation evidence

- `terraform fmt -check`: passed.
- `terraform validate`: passed with Terraform 1.12.2 and AWS provider 6.54.0.
- Protected S3 backend initialization: passed using key `dr/shared/terraform.tfstate` and native S3 locking.
- Remote speculative plan: `29 to add, 0 to change, 0 to destroy`.
- Plan output: Region `ap-southeast-1`, AZ IDs `apse1-az1` and `apse1-az2`, CIDR `10.20.0.0/16`, contract `1.0.0`.
- Plan JSON: eight subnets, two with public-IP mapping and six without; exactly two `0.0.0.0/0` routes; one S3 gateway endpoint; zero prohibited NAT, EIP, instance, or security-group resources.
- Plan outputs: `egress_mode = "none"` and `nat_public_ip = null`.

The dependency lock file contains the locally verified Windows provider checksum. Company network controls prevented obtaining the official cross-platform checksum set; this is the same documented limitation as the primary root and must be resolved before Linux-hosted CI initializes this directory.

## Cost and security decision

The plan contains no compute, managed NAT, Elastic IP, interface endpoint, ALB, database, or log ingestion. The VPC, subnets, route tables, Internet Gateway, and S3 gateway endpoint have no hourly charge; only negligible backend/S3 request and storage usage is expected. No workload can use general private Internet egress in this phase.

## Apply gate and post-apply acceptance

This plan does not authorize an apply. The exact approval phrase is:

`Approved. Apply Phase 3.`

After approval, create a fresh plan from `main`, apply only that reviewed plan, then verify the VPC CIDR/AZs, subnet public-IP settings, route-table isolation, S3 endpoint associations, Terraform state, and absence of NAT/EIP/compute. Rollback is a separately reviewed destroy and is allowed only while no consumer or recovery policy depends on the DR shared state.

The next implementation delivery after Phase 3 is the combined Phases 4-5 global/shared DNS, GitHub OIDC, and IAM work. Phase 6 freezes the shared contract; the notes application remains Phase 7A, and Gokul's EC2/RDS work remains Phase 7B after the Phase 6 handoff.
