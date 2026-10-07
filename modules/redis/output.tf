output "instance_id" {
  description = "Instance ID."
  value       = local.is_oss ? alicloud_kvstore_instance.this[0].id : alicloud_redis_tair_instance.this[0].id
}

output "connection_domain" {
  description = "Internal connection address of the instance."
  value       = local.is_oss ? alicloud_kvstore_instance.this[0].connection_domain : alicloud_redis_tair_instance.this[0].connection_domain
}

output "tags" {
  description = "Tags applied to the instance."
  value       = var.tags
}

output "generated_passwords" {
  description = "Random password of the default account under the key default. Empty when a password was supplied."
  value       = { for k, v in random_password.this : "default" => v.result }
  sensitive   = true
}
