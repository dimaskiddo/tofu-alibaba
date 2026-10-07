module "this" {
  source   = "../"
  for_each = var.instances

  name                   = each.key
  dkms_instance_id       = each.value.dkms_instance_id
  description            = try(each.value.description, null)
  key_spec               = try(each.value.key_spec, null)
  rotation_interval      = try(each.value.rotation_interval, "365d")
  pending_window_in_days = try(each.value.pending_window_in_days, null)
  deletion_protection    = try(each.value.deletion_protection, null)
  tags                   = merge(var.tags, try(each.value.tags, {}))
}
