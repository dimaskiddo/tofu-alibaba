module "this" {
  source   = "../"
  for_each = var.instances

  nat_name           = each.key
  network_type       = try(each.value.network_type, null)
  vpc_id             = each.value.vpc_id
  vpc_cidr_block     = try(each.value.vpc_cidr_block, null)
  vswitch_id         = each.value.vswitch_id
  description        = try(each.value.description, null)
  eip_allocation_ids = try(each.value.eip_allocation_ids, null)
  nat_ip_cidr        = try(each.value.nat_ip_cidr, null)
  nat_ips            = try(each.value.nat_ips, null)
  route_table_id     = try(each.value.route_table_id, null)
  tags               = merge(var.tags, try(each.value.tags, {}))
}
