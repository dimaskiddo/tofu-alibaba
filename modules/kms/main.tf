locals {
  # DescribeKey returns the period in seconds and the provider does not suppress the difference, so any other unit would diff on every plan.
  rotation_seconds = var.rotation_interval == null ? null : "${tonumber(regex("^([1-9][0-9]*)[dhms]$", var.rotation_interval)[0]) * { d = 86400, h = 3600, m = 60, s = 1 }[substr(var.rotation_interval, -1, 1)]}s"
}

resource "alicloud_kms_key" "this" {
  description            = var.description
  dkms_instance_id       = var.dkms_instance_id
  key_spec               = var.key_spec
  key_usage              = "ENCRYPT/DECRYPT"
  automatic_rotation     = var.rotation_interval == null ? "Disabled" : "Enabled"
  rotation_interval      = local.rotation_seconds
  pending_window_in_days = var.pending_window_in_days
  deletion_protection    = var.deletion_protection ? "Enabled" : "Disabled"
  tags                   = var.tags
}

resource "alicloud_kms_alias" "this" {
  alias_name = "alias/${var.name}"
  key_id     = alicloud_kms_key.this.id
}
