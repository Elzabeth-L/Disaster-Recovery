variable "name_prefix" {
  description = "Approved naming prefix for RDS resources (e.g. vaultrix-dr-primary-ec2)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the RDS security group resides."
  type        = string
}

variable "database_subnet_ids" {
  description = "List of private database subnet IDs for the DB Subnet Group."
  type        = list(string)
}

variable "source_security_group_id" {
  description = "Security group ID allowed to connect to PostgreSQL on port 5432 (EC2 security group ID)."
  type        = string
  default     = null
}

variable "db_name" {
  description = "Name of the initial database to create."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for PostgreSQL database."
  type        = string
  default     = "dbadmin"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB."
  type        = number
  default     = 20
}

variable "engine_version" {
  description = "PostgreSQL major engine version; AWS selects a currently supported minor release."
  type        = string
  default     = "16"
}

variable "common_tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}
