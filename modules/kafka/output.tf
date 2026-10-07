output "instance_id" {
  description = "Kafka instance ID."
  value       = alicloud_alikafka_instance.this.id
}

output "end_point" {
  description = "Default VPC endpoint (port 9092)."
  value       = alicloud_alikafka_instance.this.end_point
}

output "domain_endpoint" {
  description = "Default VPC domain endpoint."
  value       = alicloud_alikafka_instance.this.domain_endpoint
}

output "vpc_sasl_domain_endpoint" {
  description = "VPC SASL domain endpoint (port 9094)."
  value       = alicloud_alikafka_instance.this.vpc_sasl_domain_endpoint
}

output "topic_names" {
  description = "Topic names."
  value       = [for k, t in alicloud_alikafka_topic.this : t.topic]
}

output "consumer_group_names" {
  description = "Consumer group names."
  value       = [for k, g in alicloud_alikafka_consumer_group.this : g.consumer_id]
}

output "sasl_user_names" {
  description = "SASL user names."
  value       = [for k, u in alicloud_alikafka_sasl_user.this : u.username]
}

output "tags" {
  description = "Tags applied to the instance."
  value       = alicloud_alikafka_instance.this.tags
}

output "generated_passwords" {
  description = "Random SASL passwords keyed by user name. Users with a supplied password are absent."
  value       = { for k, v in random_password.sasl : k => v.result }
  sensitive   = true
}
