module "this" {
  source   = "../"
  for_each = var.groups

  vpc_id         = each.value.vpc_id
  vpc_cidr_block = each.value.vpc_cidr_block
  zones          = var.zones
  subnets        = each.value.subnets
  tags           = var.tags
}
