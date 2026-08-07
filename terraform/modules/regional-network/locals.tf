locals {
  availability_zone_name_by_id = zipmap(
    data.aws_availability_zones.available.zone_ids,
    data.aws_availability_zones.available.names
  )
  selected_availability_zone_ids = slice(sort(keys(local.availability_zone_name_by_id)), 0, 2)

  subnet_definitions = merge([
    for tier, cidrs in var.subnet_cidr_blocks : {
      for index, zone_id in local.selected_availability_zone_ids : "${tier}-${index + 1}" => {
        tier                      = tier
        cidr_block                = cidrs[index]
        availability_zone_id      = zone_id
        availability_zone_name    = local.availability_zone_name_by_id[zone_id]
        map_public_ip_on_launch   = tier == "public"
        load_balancer_subnet_tags = tier == "public" ? { "kubernetes.io/role/elb" = "1" } : tier == "eks_private" ? { "kubernetes.io/role/internal-elb" = "1" } : {}
      }
    }
  ]...)

  route_table_definitions = merge([
    for tier in ["public", "ec2_private", "eks_private", "database"] : {
      for index, zone_id in local.selected_availability_zone_ids : "${tier}-${index + 1}" => {
        tier                 = tier
        availability_zone_id = zone_id
      }
    }
  ]...)

  private_workload_route_table_keys = [
    for key, definition in local.route_table_definitions : key
    if contains(["ec2_private", "eks_private"], definition.tier)
  ]

  private_route_table_keys = [
    for key, definition in local.route_table_definitions : key
    if definition.tier != "public"
  ]

  nat_source_cidr_blocks = concat(
    var.subnet_cidr_blocks.ec2_private,
    var.subnet_cidr_blocks.eks_private
  )
}
