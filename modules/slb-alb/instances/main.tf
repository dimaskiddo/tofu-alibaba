module "this" {
  source   = "../"
  for_each = var.instances

  name                  = each.key
  zones                 = var.zones
  vpc_id                = each.value.vpc_id
  address_type          = try(each.value.address_type, null)
  load_balancer_edition = each.value.load_balancer_edition
  zone_mappings         = each.value.zone_mappings
  server_groups         = try(each.value.server_groups, null)
  listeners             = each.value.listeners
  rules                 = try(each.value.rules, null)
  tags                  = merge(var.tags, try(each.value.tags, {}))
}
