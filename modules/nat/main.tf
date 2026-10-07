resource "alicloud_nat_gateway" "this" {
  vpc_id           = var.vpc_id
  vswitch_id       = var.vswitch_id
  nat_gateway_name = var.nat_name
  description      = var.description
  nat_type         = "Enhanced"
  network_type     = var.network_type
  payment_type     = "PayAsYouGo"
  tags             = var.tags
}

resource "alicloud_eip_association" "this" {
  for_each = var.eip_allocation_ids

  allocation_id = each.value
  instance_id   = alicloud_nat_gateway.this.id
  instance_type = "Nat"
}

resource "alicloud_vpc_nat_ip_cidr" "this" {
  for_each = local.is_internet ? toset([]) : toset([var.nat_ip_cidr])

  nat_gateway_id   = alicloud_nat_gateway.this.id
  nat_ip_cidr      = each.value
  nat_ip_cidr_name = var.nat_name
}

resource "alicloud_vpc_nat_ip" "this" {
  for_each = local.is_internet ? {} : var.nat_ips

  nat_gateway_id = alicloud_nat_gateway.this.id
  nat_ip_cidr    = var.nat_ip_cidr
  nat_ip         = each.value.ip
  nat_ip_name    = each.key

  depends_on = [alicloud_vpc_nat_ip_cidr.this]
}

# Without this route the custom NAT IP CIDR never reaches the gateway.
resource "alicloud_route_entry" "nat_ip_cidr" {
  for_each = alicloud_vpc_nat_ip_cidr.this

  route_table_id        = var.route_table_id
  destination_cidrblock = each.value.nat_ip_cidr
  nexthop_type          = "NatGateway"
  nexthop_id            = alicloud_nat_gateway.this.id
}
