module "this" {
  source   = "../"
  for_each = var.instances

  name              = each.key
  storage_class     = try(each.value.storage_class, null)
  redundancy_type   = try(each.value.redundancy_type, null)
  visibility        = try(each.value.visibility, null)
  ram_user_id       = each.value.ram_user_id
  versioning        = try(each.value.versioning, null)
  sse_algorithm     = try(each.value.sse_algorithm, null)
  kms_master_key_id = try(each.value.kms_master_key_id, null)
  lifecycle_rules   = try(each.value.lifecycle_rules, null)
  force_destroy     = try(each.value.force_destroy, null)
  tags              = merge(var.tags, try(each.value.tags, {}))
}
