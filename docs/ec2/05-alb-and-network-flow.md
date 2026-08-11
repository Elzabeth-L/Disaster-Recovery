# 05. ALB & Network Traffic Flow — Comprehensive Notes

## 1. Network Traffic Architecture

The network design relies on a multi-tier security group boundary to isolate compute and database resources from direct internet exposure.

```
[ Public Internet Client ]
       │
       │ HTTP TCP 80 (0.0.0.0/0)
       ▼
[ ALB Security Group (*-alb-sg) ]
       │
       │ HTTP TCP 8080 (Restricted to ALB Security Group ID)
       ▼
[ EC2 Security Group (*-sg) ]
       │
       │ PostgreSQL TCP 5432 (Restricted to EC2 Security Group ID)
       ▼
[ RDS Security Group (*-rds-sg) ]
```

---

## 2. Security Group Rule Specifications

### A. ALB Security Group (`terraform/modules/alb/main.tf`)
```hcl
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_egress_app" {
  type              = "egress"
  from_port         = var.app_port
  to_port           = var.app_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}
```

---

### B. EC2 Security Group (`terraform/modules/ec2/main.tf`)
```hcl
resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-sg"
  vpc_id      = var.vpc_id
}

# Allow port 8080 ingress strictly from ALB Security Group ID
resource "aws_security_group_rule" "ingress_sgs" {
  count                    = length(var.ingress_security_group_ids)
  type                     = "ingress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = var.ingress_security_group_ids[count.index]
  security_group_id        = aws_security_group.app.id
}

# Allow outbound traffic for SSM, GHCR, and Secrets Manager
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
}
```

---

### C. RDS Security Group (`terraform/modules/rds/main.tf`)
```hcl
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  vpc_id      = var.vpc_id
}

# Allow port 5432 ingress strictly from EC2 Security Group ID
resource "aws_security_group_rule" "rds_ingress_ec2" {
  count                    = var.source_security_group_id == null ? 0 : 1
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.source_security_group_id
  security_group_id        = aws_security_group.rds.id
}
```

---

## 3. ALB Target Group Health Check Mechanics

```hcl
resource "aws_lb_target_group" "app" {
  name        = "${var.name_prefix}-tg"
  port        = var.app_port # 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-399"
  }
}
```

- **Health Probe Logic**: ALB issues HTTP GET requests to `http://<EC2_Private_IP>:8080/health` every 30 seconds.
- **Evaluation**: If 3 consecutive probes return HTTP status 200 OK, target status is marked `healthy`. If 3 probes fail or time out (> 5s), target is marked `unhealthy`.
