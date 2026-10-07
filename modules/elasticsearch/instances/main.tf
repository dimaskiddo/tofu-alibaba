module "this" {
  source   = "../"
  for_each = var.instances

  name              = each.key
  es_version        = each.value.es_version
  vswitch_id        = each.value.vswitch_id
  zone_count        = try(each.value.zone_count, null)
  data_node         = each.value.data_node
  master_node_spec  = try(each.value.master_node_spec, null)
  kibana_node_spec  = try(each.value.kibana_node_spec, null)
  protocol          = try(each.value.protocol, null)
  private_whitelist = each.value.private_whitelist
  password          = try(var.elasticsearch_passwords[each.key], null)
  password_length   = try(each.value.password_length, null)
  tags              = merge(var.tags, try(each.value.tags, {}))
}
