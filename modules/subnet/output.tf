output "subnet_ids" {
  description = "vSwitch IDs keyed by subnet name."
  value       = { for k, v in alicloud_vswitch.this : k => v.id }
}

output "subnet_cidr_blocks" {
  description = "vSwitch CIDR blocks keyed by subnet name."
  value       = { for k, v in alicloud_vswitch.this : k => v.cidr_block }
}

output "subnet_zones" {
  description = "vSwitch zone IDs keyed by subnet name."
  value       = { for k, v in alicloud_vswitch.this : k => v.zone_id }
}

output "subnet_id_list" {
  description = "vSwitch IDs ordered by subnet name."
  value       = [for k in sort(keys(alicloud_vswitch.this)) : alicloud_vswitch.this[k].id]
}

output "subnet_ids_by_zone" {
  description = "vSwitch IDs grouped by zone."
  value = {
    for z in distinct([for s in var.subnets : s.zone_id]) :
    z => [for s in var.subnets : alicloud_vswitch.this[s.name].id if s.zone_id == z]
  }
}
