locals {
  # The provider has no connection-string attribute; both resources list their access nodes instead.
  endpoints = local.is_rs ? [
    for r in alicloud_mongodb_instance.this[0].replica_sets : { role = r.replica_set_role, domain = r.connection_domain, port = tostring(r.connection_port) }
    ] : [
    for m in alicloud_mongodb_sharding_instance.this[0].mongo_list : { role = "mongos", domain = m.connect_string, port = tostring(m.port) }
  ]
}

output "instance_id" {
  description = "Instance ID."
  value       = local.is_rs ? alicloud_mongodb_instance.this[0].id : alicloud_mongodb_sharding_instance.this[0].id
}

output "replica_set_name" {
  description = "Replica set name; null for a sharded instance."
  value       = local.is_rs ? alicloud_mongodb_instance.this[0].replica_set_name : null
}

output "endpoints" {
  description = "Internal access nodes as { role, domain, port }: the replica set nodes (Primary, Secondary, ...) or the mongos routers."
  value       = local.endpoints
}

output "tags" {
  description = "Tags applied to the instance."
  value       = var.tags
}

output "generated_passwords" {
  description = "Random password of the root account under the key root. Empty when a password was supplied."
  value       = { for k, v in random_password.this : "root" => v.result }
  sensitive   = true
}
