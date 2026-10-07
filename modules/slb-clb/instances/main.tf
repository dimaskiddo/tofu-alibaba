module "this" {
  source   = "../"
  for_each = var.instances

  name                 = each.key
  zones                = var.zones
  address_type         = try(each.value.address_type, null)
  vswitch_id           = try(each.value.vswitch_id, null)
  master_zone_id       = try(each.value.master_zone_id, null)
  slave_zone_id        = try(each.value.slave_zone_id, null)
  load_balancer_spec   = try(each.value.load_balancer_spec, null)
  internet_charge_type = try(each.value.internet_charge_type, null)
  bandwidth            = try(each.value.bandwidth, null)
  backend_servers      = try(each.value.backend_servers, null)
  listeners            = each.value.listeners
  tags                 = merge(var.tags, try(each.value.tags, {}))
}
