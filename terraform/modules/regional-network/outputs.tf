output "vpc_id" {
  description = "Regional shared VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "Regional shared VPC IPv4 CIDR."
  value       = aws_vpc.this.cidr_block
}

output "availability_zone_ids" {
  description = "Deterministically ordered AZ IDs used by every subnet tier."
  value       = local.selected_availability_zone_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs ordered by availability_zone_ids."
  value       = [for index in range(2) : aws_subnet.this["public-${index + 1}"].id]
}

output "ec2_private_subnet_ids" {
  description = "EC2 private subnet IDs ordered by availability_zone_ids."
  value       = [for index in range(2) : aws_subnet.this["ec2_private-${index + 1}"].id]
}

output "eks_private_subnet_ids" {
  description = "EKS private subnet IDs ordered by availability_zone_ids."
  value       = [for index in range(2) : aws_subnet.this["eks_private-${index + 1}"].id]
}

output "database_subnet_ids" {
  description = "Database subnet IDs ordered by availability_zone_ids."
  value       = [for index in range(2) : aws_subnet.this["database-${index + 1}"].id]
}

output "private_route_table_ids" {
  description = "Private route-table IDs grouped by consumer contract key and ordered by AZ ID."
  value = {
    ec2      = [for index in range(2) : aws_route_table.this["ec2_private-${index + 1}"].id]
    eks      = [for index in range(2) : aws_route_table.this["eks_private-${index + 1}"].id]
    database = [for index in range(2) : aws_route_table.this["database-${index + 1}"].id]
  }
}

output "s3_gateway_endpoint_id" {
  description = "S3 gateway endpoint managed by the regional shared state."
  value       = aws_vpc_endpoint.s3.id
}

output "egress_mode" {
  description = "Selected private workload egress implementation."
  value       = var.egress_mode
}

output "nat_public_ip" {
  description = "Public NAT address when an egress device is enabled."
  value = var.egress_mode == "nat_instance" ? aws_eip.nat_instance[0].public_ip : (
    var.egress_mode == "nat_gateway" ? aws_eip.nat_gateway[0].public_ip : null
  )
}
