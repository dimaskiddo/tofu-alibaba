output "subnet_ids" {
  description = "vSwitch IDs keyed by subnet name, across all VPC groups."
  value       = merge([for m in module.this : m.subnet_ids]...)
}

output "subnet_cidr_blocks" {
  description = "vSwitch CIDR blocks keyed by subnet name, across all VPC groups."
  value       = merge([for m in module.this : m.subnet_cidr_blocks]...)
}

output "subnet_zones" {
  description = "vSwitch zone IDs keyed by subnet name, across all VPC groups."
  value       = merge([for m in module.this : m.subnet_zones]...)
}

output "groups" {
  description = "All outputs of ../ per VPC group."
  value       = { for k, m in module.this : k => m }
}
