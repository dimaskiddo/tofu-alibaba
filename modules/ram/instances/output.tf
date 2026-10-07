output "instances" {
  description = "All outputs of ../ per instance, keyed by instance name, without generated_passwords."
  value       = { for k, m in module.this : k => { for a, v in m : a => v if a != "generated_passwords" } }
}

output "generated_passwords" {
  description = "AccessKey ID and secret keyed by instance name."
  value       = { for k, m in module.this : k => m.generated_passwords }
  sensitive   = true
}
