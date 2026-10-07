resource "alicloud_snat_entry" "this" {
  for_each = local.entries

  snat_table_id     = var.snat_table_id
  snat_entry_name   = each.key
  snat_ip           = join(",", var.snat_ips)
  source_cidr       = each.value.source_cidr
  source_vswitch_id = each.value.source_vswitch_id
}
