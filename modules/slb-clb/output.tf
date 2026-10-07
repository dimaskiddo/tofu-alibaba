output "tags" {
  description = "Tags applied to the load balancer."
  value       = alicloud_slb_load_balancer.this.tags
}

output "load_balancer_id" {
  description = "CLB ID."
  value       = alicloud_slb_load_balancer.this.id
}

output "address" {
  description = "CLB IP address."
  value       = alicloud_slb_load_balancer.this.address
}

output "server_group_id" {
  description = "vServer group ID (null when no backend_servers)."
  value       = one([for v in alicloud_slb_server_group.this : v.id])
}

output "frontend_ports" {
  description = "Frontend port keyed by listener name."
  value       = { for k, v in var.listeners : k => v.frontend_port }
}
