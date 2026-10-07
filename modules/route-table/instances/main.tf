module "this" {
  source   = "../"
  for_each = var.instances

  route_table_id   = try(each.value.route_table_id, null)
  vpc_id           = try(each.value.vpc_id, null)
  route_table_name = try(each.value.route_table_name, null)
  description      = try(each.value.description, null)
  vswitch_ids      = try(each.value.vswitch_ids, null)
  routes           = try(each.value.routes, null)
  tags             = merge(var.tags, try(each.value.tags, {}))
}
