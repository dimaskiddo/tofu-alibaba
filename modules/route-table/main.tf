resource "alicloud_route_table" "this" {
  count = var.route_table_id == null ? 1 : 0

  vpc_id           = var.vpc_id
  route_table_name = var.route_table_name
  description      = var.description
  associate_type   = "VSwitch"
  tags             = var.tags
}

locals {
  route_table_id = var.route_table_id == null ? alicloud_route_table.this[0].id : var.route_table_id
}

resource "alicloud_route_table_attachment" "this" {
  for_each = var.vswitch_ids

  route_table_id = local.route_table_id
  vswitch_id     = each.value
}

resource "alicloud_route_entry" "this" {
  for_each = var.routes

  route_table_id        = local.route_table_id
  destination_cidrblock = each.value.destination_cidrblock
  nexthop_type          = each.value.nexthop_type
  nexthop_id            = each.value.nexthop_id
  name                  = each.key
  description           = each.value.description

  depends_on = [alicloud_route_table_attachment.this]
}
