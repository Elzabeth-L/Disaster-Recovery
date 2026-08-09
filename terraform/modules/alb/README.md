# Reusable ALB Module

This module provisions an internet-facing Application Load Balancer with:
- Dedicated ALB Security Group allowing HTTP 80 ingress from `0.0.0.0/0`.
- Placed in public subnets (`var.public_subnet_ids`).
- HTTP listener forwarding port 80 to target group on port 8080.
- Target group registered with private EC2 instance.
- Configurable health checks (`var.health_check_path`, default `/health`).
