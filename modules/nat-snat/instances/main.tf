module "this" {
  source   = "../"
  for_each = var.instances

  snat_table_id = each.value.snat_table_id
  snat_ips      = each.value.snat_ips
  entries       = each.value.entries
  tags          = merge(var.tags, try(each.value.tags, {}))
}
