# Reusable RDS PostgreSQL Module

This module provisions a private AWS RDS PostgreSQL instance with:
- Dedicated RDS Security Group (`aws_security_group.rds`) permitting TCP 5432 ingress strictly from a source security group ID (EC2 SG).
- DB Subnet Group across private database subnets (`database_subnet_ids`).
- Private placement (`publicly_accessible = false`).
- Encrypted storage (`storage_encrypted = true`, gp3).
- Master password generated via `random_password` and stored securely in AWS Secrets Manager as connection JSON (`engine`, `host`, `port`, `dbname`, `username`, `password`).
- Zero secret credentials exposed in Terraform outputs.
