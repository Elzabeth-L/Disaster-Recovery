# Reusable EC2 Application Instance Module

This module provisions a private AWS EC2 instance foundation with:
- Dedicated Security Group (`aws_security_group`) with configurable ingress rules and full egress for SSM & package endpoints.
- IAM Instance Profile with `AmazonSSMManagedInstanceCore` policy attached for Systems Manager access without SSH keys.
- IMDSv2 enforced (`http_tokens = "required"`).
- Encrypted gp3 root block device.
- Placed in private EC2 subnet with `associate_public_ip_address = false`.
