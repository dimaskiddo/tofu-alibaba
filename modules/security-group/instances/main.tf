module "this" {
  source   = "../"
  for_each = var.instances

  name                = each.key
  vpc_id              = each.value.vpc_id
  description         = try(each.value.description, null)
  inner_access_policy = try(each.value.inner_access_policy, null)
  rules               = try(each.value.rules, null)
  tags                = merge(var.tags, try(each.value.tags, {}))
}
