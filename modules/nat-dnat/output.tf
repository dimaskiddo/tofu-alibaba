output "dnat_entry_ids" {
  description = "DNAT entry IDs keyed by entry name."
  value       = { for k, v in alicloud_forward_entry.this : k => v.forward_entry_id }
}
