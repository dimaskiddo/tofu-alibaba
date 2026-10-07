output "tags" {
  description = "Tags applied to the package."
  value       = alicloud_common_bandwidth_package.this.tags
}

output "bandwidth_package_id" {
  description = "Package ID."
  value       = alicloud_common_bandwidth_package.this.id
}

output "eip_names" {
  description = "Names of the attached EIPs."
  value       = sort(keys(alicloud_common_bandwidth_package_attachment.this))
}

output "alb_names" {
  description = "Names of the attached ALBs."
  value       = sort(keys(alicloud_alb_load_balancer_common_bandwidth_package_attachment.this))
}
