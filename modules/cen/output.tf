output "cen_id" {
  description = "CEN instance ID (the created one, or the cen_id input)."
  value       = local.cen_id
}

output "transit_router_id" {
  description = "Transit router ID of this region."
  value       = alicloud_cen_transit_router.this.transit_router_id
}

output "route_table_id" {
  description = "System route table ID of the transit router."
  value       = local.table_id
}

output "attachment_ids" {
  description = "VPC and peer attachment IDs by name; usable as an Attachment route next hop, or as another region's remote_attachment_ids."
  value       = local.attachment_ids
}

output "tags" {
  description = "Tags applied to the transit router."
  value       = alicloud_cen_transit_router.this.tags
}
