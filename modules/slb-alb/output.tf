output "tags" {
  description = "Tags applied to the load balancer."
  value       = alicloud_alb_load_balancer.this.tags
}

output "load_balancer_id" {
  description = "ALB ID."
  value       = alicloud_alb_load_balancer.this.id
}

output "dns_name" {
  description = "ALB DNS name."
  value       = alicloud_alb_load_balancer.this.dns_name
}

output "zone_ids" {
  description = "Zones the ALB is deployed in."
  value       = [for z in var.zone_mappings : z.zone_id]
}

output "server_group_ids" {
  description = "Server group IDs keyed by name."
  value       = { for k, v in alicloud_alb_server_group.this : k => v.id }
}

output "listener_ids" {
  description = "Listener IDs keyed by name."
  value       = { for k, v in alicloud_alb_listener.this : k => v.id }
}

output "rule_ids" {
  description = "Rule IDs keyed by name."
  value       = { for k, v in alicloud_alb_rule.this : k => v.id }
}
