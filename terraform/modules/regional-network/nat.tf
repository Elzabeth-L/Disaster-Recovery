data "aws_ssm_parameter" "nat_ami" {
  count = var.egress_mode == "nat_instance" ? 1 : 0

  name = var.nat_instance_ami_ssm_parameter
}

resource "aws_security_group" "nat_instance" {
  count = var.egress_mode == "nat_instance" ? 1 : 0

  name_prefix = "${var.name_prefix}-nat-"
  description = "Forward private EC2 and EKS egress through the NAT instance"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-nat-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "nat_from_private" {
  for_each = var.egress_mode == "nat_instance" ? toset(local.nat_source_cidr_blocks) : toset([])

  security_group_id = aws_security_group.nat_instance[0].id
  description       = "Forward traffic from private workload subnet ${each.value}"
  cidr_ipv4         = each.value
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "nat_to_anywhere" {
  count = var.egress_mode == "nat_instance" ? 1 : 0

  security_group_id = aws_security_group.nat_instance[0].id
  description       = "NAT instance outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "nat" {
  count = var.egress_mode == "nat_instance" ? 1 : 0

  ami                         = data.aws_ssm_parameter.nat_ami[0].value
  instance_type               = var.nat_instance_type
  subnet_id                   = aws_subnet.this["public-1"].id
  vpc_security_group_ids      = [aws_security_group.nat_instance[0].id]
  associate_public_ip_address = true
  source_dest_check           = false
  user_data = templatefile("${path.module}/templates/nat-instance.sh.tftpl", {
    nat_source_cidr_blocks = local.nat_source_cidr_blocks
  })
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 8
  }

  credit_specification {
    cpu_credits = "standard"
  }

  tags = {
    Name = "${var.name_prefix}-nat-instance"
  }

  depends_on = [aws_route.public_internet]
}

resource "aws_eip" "nat_instance" {
  count = var.egress_mode == "nat_instance" ? 1 : 0

  domain   = "vpc"
  instance = aws_instance.nat[0].id

  tags = {
    Name = "${var.name_prefix}-nat-instance-eip"
  }
}

resource "aws_eip" "nat_gateway" {
  count = var.egress_mode == "nat_gateway" ? 1 : 0

  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-nat-gateway-eip"
  }
}

resource "aws_nat_gateway" "this" {
  count = var.egress_mode == "nat_gateway" ? 1 : 0

  allocation_id     = aws_eip.nat_gateway[0].id
  subnet_id         = aws_subnet.this["public-1"].id
  connectivity_type = "public"

  tags = {
    Name = "${var.name_prefix}-nat-gateway"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route" "private_via_nat_instance" {
  for_each = var.egress_mode == "nat_instance" ? toset(local.private_workload_route_table_keys) : toset([])

  route_table_id         = aws_route_table.this[each.value].id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat[0].primary_network_interface_id
}

resource "aws_route" "private_via_nat_gateway" {
  for_each = var.egress_mode == "nat_gateway" ? toset(local.private_workload_route_table_keys) : toset([])

  route_table_id         = aws_route_table.this[each.value].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}
