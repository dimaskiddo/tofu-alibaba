output "security_group_id" {
  description = "Security group ID."
  value       = alicloud_security_group.this.id
}

output "security_group_name" {
  description = "Security group name."
  value       = alicloud_security_group.this.security_group_name
}

output "rule_ids" {
  description = "Security group rule IDs keyed by rule name."
  value       = { for k, v in alicloud_security_group_rule.this : k => v.security_group_rule_id }
}

output "tags" {
  description = "Tags applied to the security group."
  value       = alicloud_security_group.this.tags
}
