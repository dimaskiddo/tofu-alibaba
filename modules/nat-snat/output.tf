output "snat_entry_ids" {
  description = "SNAT entry IDs keyed by entry name."
  value       = { for k, v in alicloud_snat_entry.this : k => v.snat_entry_id }
}

output "snat_ip" {
  description = "Translated source IPs, comma separated."
  value       = join(",", var.snat_ips)
}
