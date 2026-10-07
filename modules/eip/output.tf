output "eip_ids" {
  description = "EIP allocation IDs keyed by EIP name."
  value       = { for k, v in alicloud_eip_address.this : k => v.id }
}

output "eip_addresses" {
  description = "EIP public IP addresses keyed by EIP name."
  value       = { for k, v in alicloud_eip_address.this : k => v.ip_address }
}

output "tags" {
  description = "Tags applied to each EIP, keyed by EIP name."
  value       = { for k, v in alicloud_eip_address.this : k => v.tags }
}
