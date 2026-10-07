output "nat_gateway_id" {
  description = "NAT gateway ID."
  value       = alicloud_nat_gateway.this.id
}

output "network_type" {
  description = "internet or intranet."
  value       = var.network_type
}

output "snat_table_ids" {
  description = "SNAT table ID auto-created with the gateway."
  value       = alicloud_nat_gateway.this.snat_table_ids
}

output "forward_table_ids" {
  description = "DNAT (forward) table ID auto-created with the gateway."
  value       = alicloud_nat_gateway.this.forward_table_ids
}

output "nat_ips" {
  description = "Private NAT IP addresses keyed by name (empty for internet)."
  value       = { for k, v in alicloud_vpc_nat_ip.this : k => v.nat_ip }
}

output "tags" {
  description = "Tags applied to the NAT gateway."
  value       = alicloud_nat_gateway.this.tags
}
