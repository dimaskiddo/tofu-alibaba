module "this" {
  source   = "../"
  for_each = var.instances

  name     = each.key
  comments = try(each.value.comments, null)
  tags     = merge(var.tags, try(each.value.tags, {}))
}
