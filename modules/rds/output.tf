output "instance_id" {
  description = "RDS instance ID."
  value       = alicloud_db_instance.this.id
}

output "connection_string" {
  description = "Internal connection address of the instance."
  value       = alicloud_db_instance.this.connection_string
}

output "port" {
  description = "Connection port."
  value       = alicloud_db_instance.this.port
}

output "database_names" {
  description = "Database names."
  value       = [for k, d in alicloud_db_database.this : d.data_base_name]
}

output "account_names" {
  description = "Account names."
  value       = [for k, a in alicloud_rds_account.this : a.account_name]
}

output "tags" {
  description = "Tags applied to the instance."
  value       = alicloud_db_instance.this.tags
}

output "generated_passwords" {
  description = "Random account passwords keyed by account name. Accounts with a supplied password are absent."
  value       = { for k, v in random_password.account : k => v.result }
  sensitive   = true
}
