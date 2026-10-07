output "vpc_id" {
  description = "VPC ID."
  value       = alicloud_vpc.this.id
}

output "vpc_name" {
  description = "VPC name."
  value       = alicloud_vpc.this.vpc_name
}

output "cidr_block" {
  description = "VPC CIDR block."
  value       = alicloud_vpc.this.cidr_block
}

output "tags" {
  description = "Tags applied to the VPC."
  value       = alicloud_vpc.this.tags
}

output "route_table_id" {
  description = "System route table ID."
  value       = alicloud_vpc.this.route_table_id
}
