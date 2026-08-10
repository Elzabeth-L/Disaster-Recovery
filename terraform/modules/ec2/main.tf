# Select Amazon Linux 2023 AMI if custom AMI ID is not specified
data "aws_ami" "al2023" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.al2023[0].id

  default_user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    app_image     = var.app_image
    app_env       = var.app_env
    db_secret_arn = var.db_secret_arn != null ? var.db_secret_arn : ""
  })

  user_data = var.user_data != null ? var.user_data : local.default_user_data
}

# Dedicated EC2 Application Security Group
resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-sg"
  description = "Security group for EC2 application instances"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-sg"
    }
  )
}

# Security group ingress rule for allowed Security Groups (e.g. ALB SG)
resource "aws_security_group_rule" "ingress_sgs" {
  count                    = length(var.ingress_security_group_ids)
  type                     = "ingress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = var.ingress_security_group_ids[count.index]
  security_group_id        = aws_security_group.app.id
}

# Security group ingress rule for allowed CIDRs (internal network / VPC)
resource "aws_security_group_rule" "ingress_cidrs" {
  count             = length(var.ingress_cidr_blocks) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = var.app_port
  to_port           = var.app_port
  protocol          = "tcp"
  cidr_blocks       = var.ingress_cidr_blocks
  security_group_id = aws_security_group.app.id
}

# Egress rule allowing outbound traffic for SSM, S3 gateway endpoint, Secrets Manager, and package repositories
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
}

# IAM Role for SSM Access (no SSH key required)
resource "aws_iam_role" "ssm" {
  name        = "${var.name_prefix}-ssm-role"
  description = "IAM role allowing EC2 instance to be managed by Systems Manager (SSM)"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-ssm-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Tightly-scoped IAM policy statement allowing reading specific RDS secret in Secrets Manager
resource "aws_iam_role_policy" "read_db_secret" {
  count = var.enable_db_secret_access ? 1 : 0
  name  = "${var.name_prefix}-read-db-secret"
  role  = aws_iam_role.ssm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [var.db_secret_arn]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.name_prefix}-instance-profile"
  role = aws_iam_role.ssm.name

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-instance-profile"
    }
  )
}

# EC2 Instance placed in private subnet with IMDSv2 and encrypted root volume
resource "aws_instance" "app" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app.name

  associate_public_ip_address = false
  user_data                   = local.user_data
  user_data_replace_on_change = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-instance"
    }
  )

  lifecycle {
    ignore_changes = [
      ami
    ]
  }
}
