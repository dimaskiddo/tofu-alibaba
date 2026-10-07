output "instances" {
  description = "All outputs of ../ per instance, keyed by instance name."
  value       = { for k, m in module.this : k => m }
}

output "attachment_ids" {
  description = "Attachment IDs of every instance by attachment name; attachment names are unique across instances."
  value       = merge([for m in module.this : m.attachment_ids]...)
}
