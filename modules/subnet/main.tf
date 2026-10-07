resource "alicloud_vswitch" "this" {
  for_each = local.subnets

  vpc_id       = var.vpc_id
  vswitch_name = each.value.name
  cidr_block   = each.value.cidr_block
  zone_id      = each.value.zone_id
  tags         = merge(var.tags, each.value.tags)
}
