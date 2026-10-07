module "this" {
  source   = "../"
  for_each = var.instances

  forward_table_id = each.value.forward_table_id
  entries          = each.value.entries
  tags             = merge(var.tags, try(each.value.tags, {}))
}
