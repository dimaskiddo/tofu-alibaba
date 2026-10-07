module "this" {
  source   = "../"
  for_each = var.instances

  peer_name                = each.key
  vpc_id                   = each.value.vpc_id
  vpc_cidr_block           = each.value.vpc_cidr_block
  accepting_vpc_id         = each.value.accepting_vpc_id
  accepting_vpc_cidr_block = each.value.accepting_vpc_cidr_block
  accepting_region_id      = each.value.accepting_region_id
  accepting_ali_uid        = try(each.value.accepting_ali_uid, null)
  bandwidth                = try(each.value.bandwidth, null)
  link_type                = try(each.value.link_type, null)
  route_table_id           = try(each.value.route_table_id, null)
  accepting_route_table_id = try(each.value.accepting_route_table_id, null)
  description              = try(each.value.description, null)
  tags                     = merge(var.tags, try(each.value.tags, {}))
}
