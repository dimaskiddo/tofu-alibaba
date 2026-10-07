module "this" {
  source   = "../"
  for_each = var.instances

  vpc_name    = each.key
  cidr_block  = each.value.cidr_block
  description = try(each.value.description, null)
  tags        = merge(var.tags, try(each.value.tags, {}))
}
