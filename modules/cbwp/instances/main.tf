module "this" {
  source   = "../"
  for_each = var.instances

  name                 = each.key
  bandwidth            = each.value.bandwidth
  internet_charge_type = try(each.value.internet_charge_type, null)
  isp                  = try(each.value.isp, null)
  description          = try(each.value.description, null)
  deletion_protection  = try(each.value.deletion_protection, null)
  eip_ids              = try(each.value.eip_ids, null)
  alb_ids              = try(each.value.alb_ids, null)
  tags                 = merge(var.tags, try(each.value.tags, {}))
}
