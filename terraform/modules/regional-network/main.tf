data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_subnet" "this" {
  for_each = local.subnet_definitions

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr_block
  availability_zone_id    = each.value.availability_zone_id
  map_public_ip_on_launch = each.value.map_public_ip_on_launch

  tags = merge(
    {
      Name        = "${var.name_prefix}-${replace(each.key, "_", "-")}-subnet"
      NetworkTier = replace(each.value.tier, "_", "-")
    },
    each.value.load_balancer_subnet_tags
  )
}

resource "aws_route_table" "this" {
  for_each = local.route_table_definitions

  vpc_id = aws_vpc.this.id

  tags = {
    Name             = "${var.name_prefix}-${replace(each.key, "_", "-")}-rt"
    NetworkTier      = replace(each.value.tier, "_", "-")
    AvailabilityZone = each.value.availability_zone_id
  }
}

resource "aws_route_table_association" "this" {
  for_each = local.subnet_definitions

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[each.key].id
}

resource "aws_route" "public_internet" {
  for_each = {
    for key, definition in local.route_table_definitions : key => definition
    if definition.tier == "public"
  }

  route_table_id         = aws_route_table.this[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    for key in local.private_route_table_keys : aws_route_table.this[key].id
  ]

  tags = {
    Name = "${var.name_prefix}-s3-endpoint"
  }
}

data "aws_region" "current" {}

check "two_standard_availability_zones" {
  assert {
    condition     = length(local.selected_availability_zone_ids) == 2
    error_message = "The selected Region must expose at least two standard Availability Zones."
  }
}
