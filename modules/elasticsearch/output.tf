output "instance_id" {
  description = "Elasticsearch instance ID."
  value       = alicloud_elasticsearch_instance.this.id
}

output "domain" {
  description = "Internal domain of the instance."
  value       = alicloud_elasticsearch_instance.this.domain
}

output "port" {
  description = "Connection port."
  value       = alicloud_elasticsearch_instance.this.port
}

output "kibana_domain" {
  description = "Public Kibana endpoint (public access is never enabled, so this is not the one to use)."
  value       = alicloud_elasticsearch_instance.this.kibana_domain
}

output "kibana_private_domain" {
  description = "Private Kibana endpoint inside the VPC (empty without a Kibana node)."
  value       = alicloud_elasticsearch_instance.this.kibana_private_domain
}

output "kibana_port" {
  description = "Kibana port."
  value       = alicloud_elasticsearch_instance.this.kibana_port
}

output "tags" {
  description = "Tags applied to the instance."
  value       = alicloud_elasticsearch_instance.this.tags
}

output "generated_passwords" {
  description = "Random password of the elastic account under the key elastic. Empty when a password was supplied."
  value       = { for k, v in random_password.this : "elastic" => v.result }
  sensitive   = true
}
