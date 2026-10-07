output "tags" {
  description = "Tags applied to the user."
  value       = alicloud_ram_user.this.tags
}

output "user_name" {
  description = "RAM user name."
  value       = alicloud_ram_user.this.name
}

output "user_id" {
  description = "RAM user ID (UserId); the principal in resource policies."
  value       = alicloud_ram_user.this.id
}

output "access_key_id" {
  description = "AccessKey ID of the user."
  value       = alicloud_ram_access_key.this.id
}

output "generated_passwords" {
  description = "AccessKey ID and secret of the user. Printed by the Atlantis workflow (owner decision 2026-10-02); do not reuse this output name."
  value = {
    access_key_id     = alicloud_ram_access_key.this.id
    access_key_secret = alicloud_ram_access_key.this.secret
  }
  sensitive = true
}
