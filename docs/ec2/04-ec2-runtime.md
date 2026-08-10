# 04. EC2 Instance Runtime & Bootstrap — Comprehensive Notes

## 1. Compute Configuration Overview

The EC2 application compute instance is provisioned by [`terraform/modules/ec2/main.tf`](file:///c:/Users/smine/Disaster-Recovery/terraform/modules/ec2/main.tf). It operates within an isolated private subnet without a public IP address.

```
+-------------------------------------------------------------------------+
|                          EC2 COMPUTE SPECIFICATION                      |
+--------------------------+----------------------------------------------+
| AMI                      | Amazon Linux 2023 (al2023-ami-2023.*-x86_64) |
| Instance Type            | t3.micro                                     |
| Network Placement        | Private Subnet (associate_public_ip_address=false)|
| Storage                  | 20 GB gp3 Root Volume (Encrypted at rest)    |
| Metadata Service         | IMDSv2 Enforced (http_tokens=required)       |
| Process Supervisor       | Systemd (vaultrix-app.service)               |
| Remote Access            | Keyless via AWS Systems Manager (SSM)        |
+--------------------------+----------------------------------------------+
```

---

## 2. Cloud-Init User Data Execution Flow (`user_data.sh.tftpl`)

When the instance starts, AWS Cloud-Init executes the template script rendered by Terraform:

```bash
#!/bin/bash
set -euo pipefail

# Redirect output to user-data.log for SSM debugging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/null) 2>&1

echo "[$(date)] Starting VaultRix EC2 Application Deployment..."

# Install Docker on Amazon Linux 2023
if ! command -v docker &> /dev/null; then
    echo "[$(date)] Installing Docker via dnf..."
    dnf update -y
    dnf install -y docker
fi

# Enable and start Docker daemon
systemctl enable docker
systemctl start docker

# Create systemd service for VaultRix Tasks container
cat << 'EOF' > /etc/systemd/system/vaultrix-app.service
[Unit]
Description=VaultRix Tasks Container Application
After=docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=10
ExecStartPre=-/usr/bin/docker stop vaultrix-app
ExecStartPre=-/usr/bin/docker rm vaultrix-app
ExecStartPre=/usr/bin/docker pull ${app_image}
ExecStart=/usr/bin/docker run --name vaultrix-app \
  -p 8080:8080 \
  -e APP_ENV=${app_env} \
  -e DB_SECRET_ARN=${db_secret_arn} \
  ${app_image}
ExecStop=/usr/bin/docker stop vaultrix-app

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start application service
systemctl daemon-reload
systemctl enable vaultrix-app.service
systemctl restart vaultrix-app.service

echo "[$(date)] VaultRix Tasks Container Application deployment initiated successfully."
```

### Systemd Unit Breakdown (`vaultrix-app.service`)
- `After=docker.service`: Guarantees Docker daemon is active before starting the app container.
- `Restart=always` & `RestartSec=10`: Instructs Systemd to automatically restart the container process within 10 seconds if Gunicorn or Docker crashes.
- `ExecStartPre=-/usr/bin/docker stop vaultrix-app` (and `rm`): Ensures any leftover container instance is cleaned up prior to start.
- `ExecStartPre=/usr/bin/docker pull ${app_image}`: Pulls the newest container tag from GHCR during every service start or restart.

---

## 3. Keyless SSM Architecture & Instance Security

SSH Port 22 is disabled across all security groups. Instead, management access is facilitated through **AWS Systems Manager (SSM) Session Manager**.

```hcl
# IAM Role for SSM Access (no SSH key required)
resource "aws_iam_role" "ssm" {
  name        = "${var.name_prefix}-ssm-role"
  description = "IAM role allowing EC2 instance to be managed by Systems Manager (SSM)"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

### Operator Login Workflow
As detailed in [`docs/human-operator-access.md`](file:///c:/Users/smine/Disaster-Recovery/docs/human-operator-access.md), operators log into the AWS Console as `vaultrix-dr-ec2-operator` or use the CLI:

```bash
# Connect to Primary EC2 Instance
INSTANCE_ID=$(aws ec2 describe-instances --region ap-south-1 \
  --filters "Name=tag:Name,Values=vaultrix-dr-primary-ec2-instance" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" --output text)

aws ssm start-session --region ap-south-1 --target "$INSTANCE_ID"
```
