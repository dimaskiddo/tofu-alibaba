output "instances" {
  description = "All outputs of ../ per instance, keyed by instance name."
  value       = { for k, m in module.this : k => m }
}
