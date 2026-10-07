output "route_table_id" {
  description = "Route table ID, created or supplied."
  value       = local.route_table_id
}

output "route_entry_ids" {
  description = "Route entry IDs keyed by route name."
  value       = { for k, v in alicloud_route_entry.this : k => v.id }
}

output "tags" {
  description = "Tags of the custom route table; null when routes are added to an existing table, which is not tagged."
  value       = one(alicloud_route_table.this[*].tags)
}
