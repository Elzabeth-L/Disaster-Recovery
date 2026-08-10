# Generate secure initial database password
resource "random_password" "master" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Dedicated RDS Security Group allowing port 5432 strictly from source security group (EC2 SG)
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "Security group for private RDS PostgreSQL instance"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-rds-sg"
    }
  )
}

resource "aws_security_group_rule" "rds_ingress_ec2" {
  count                    = var.source_security_group_id == null ? 0 : 1
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.source_security_group_id
  security_group_id        = aws_security_group.rds.id
}

# DB Subnet Group across isolated database subnets
resource "aws_db_subnet_group" "main" {
  name        = "${var.name_prefix}-db-subnet-group"
  subnet_ids  = var.database_subnet_ids
  description = "Database subnet group for primary RDS PostgreSQL instance"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-db-subnet-group"
    }
  )
}

# Private RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  identifier             = "${var.name_prefix}-rds"
  engine                 = "postgres"
  engine_version         = var.engine_version
  instance_class         = var.instance_class
  allocated_storage      = var.allocated_storage
  max_allocated_storage  = 50
  storage_type           = "gp3"
  storage_encrypted      = true
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  db_name  = var.db_name
  username = var.db_username
  password = random_password.master.result
  port     = 5432

  backup_retention_period     = 1
  backup_window               = "03:00-04:00"
  maintenance_window          = "Mon:04:00-Mon:05:00"
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false

  skip_final_snapshot = true
  deletion_protection = false

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-rds"
    }
  )
}

# AWS Secrets Manager Secret for DB Credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.name_prefix}-db-credentials"
  description             = "Database credentials for primary RDS PostgreSQL instance"
  recovery_window_in_days = 0

  tags = merge(
    var.common_tags,
    {
      Name = "${var.name_prefix}-db-credentials"
    }
  )
}

# AWS Secrets Manager Secret Version storing connection JSON
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
    username = var.db_username
    password = random_password.master.result
  })
}
