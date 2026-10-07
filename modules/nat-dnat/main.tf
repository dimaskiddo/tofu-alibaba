resource "alicloud_forward_entry" "this" {
  for_each = local.entries

  forward_table_id   = var.forward_table_id
  forward_entry_name = each.key
  external_ip        = each.value.external_ip
  external_port      = each.value.external_port
  internal_ip        = each.value.internal_ip
  internal_port      = each.value.internal_port
  ip_protocol        = each.value.ip_protocol
  port_break         = each.value.port_break
}
