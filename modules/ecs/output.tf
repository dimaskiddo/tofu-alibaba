output "instance_ids" {
  description = "Instance IDs keyed by instance name."
  value       = { for k, v in alicloud_instance.this : k => v.id }
}

output "private_ips" {
  description = "Primary private IPs keyed by instance name."
  value       = { for k, v in alicloud_instance.this : k => v.primary_ip_address }
}

output "public_ips" {
  description = "Public IPs keyed by instance name (empty when no public bandwidth is set)."
  value       = { for k, v in alicloud_instance.this : k => v.public_ip }
}

output "instance_by_name" {
  description = "Instance ID, private IP and zone keyed by instance name."
  value = {
    for k, v in alicloud_instance.this : k => {
      id         = v.id
      private_ip = v.primary_ip_address
      zone_id    = v.availability_zone
    }
  }
}

output "data_disk_ids" {
  description = "Data disk IDs keyed by <instance>/<disk name>."
  value       = { for k, v in alicloud_ecs_disk.data : k => v.id }
}

output "generated_passwords" {
  description = "Random login passwords keyed by instance name. Instances with a key pair or a supplied password are absent."
  value       = { for k, v in random_password.login : k => v.result }
  sensitive   = true
}
