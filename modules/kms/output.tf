output "tags" {
  description = "Tags applied to the key."
  value       = alicloud_kms_key.this.tags
}

output "rotation_interval" {
  description = "Rotation period in seconds as sent to and read back from the API (null when rotation is disabled)."
  value       = alicloud_kms_key.this.rotation_interval
}

output "automatic_rotation" {
  description = "Enabled or Disabled."
  value       = alicloud_kms_key.this.automatic_rotation
}

output "key_id" {
  description = "KMS key ID, the value ECS disks and RDS take as their key."
  value       = alicloud_kms_key.this.id
}

output "arn" {
  description = "KMS key ARN."
  value       = alicloud_kms_key.this.arn
}

output "alias" {
  description = "Key alias, alias/<name>."
  value       = alicloud_kms_alias.this.alias_name
}
