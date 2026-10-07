include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "storage_class", "redundancy_type", "visibility", "ram_user",
    "versioning", "sse_algorithm", "kms_master_key_id", "kms_key", "lifecycle_rules", "force_destroy",
  ]
  unknown = [
    for n, f in include.root.locals.instances : "instance ${n}: unknown key(s) ${join(", ", sort(setsubtract(keys(f), local.known)))}"
    if length(setsubtract(keys(f), local.known)) > 0
  ]
  keys_ok  = lookup({ ok = "ok" }, length(local.unknown) == 0 ? "ok" : join("; ", local.unknown))
  kms_both = [for n, f in include.root.locals.instances : "instance ${n}: set kms_key or kms_master_key_id, not both" if can(f.kms_key) && can(f.kms_master_key_id)]
  kms_ok   = lookup({ ok = "ok" }, length(local.kms_both) == 0 ? "ok" : join("; ", local.kms_both))
  members  = { for n, f in include.root.locals.instances : n => f if local.keys_ok == "ok" && local.kms_ok == "ok" }
  kms_keys = distinct([for f in values(local.members) : f.kms_key if can(f.kms_key)])
}

dependency "ram" {
  config_path = "../ram"

  mock_outputs = {
    instances = { for u in distinct([for f in values(local.members) : f.ram_user]) : u => { user_id = "200000000000000" } }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "kms" {
  config_path = "../kms"
  enabled     = length(local.kms_keys) > 0

  mock_outputs = {
    instances = { for k in local.kms_keys : k => { key_id = "key-mock" } }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

terraform {
  source = "${include.root.locals.modules_dir}//oss/instances"
}

inputs = {
  instances = {
    for n, f in local.members : n => {
      storage_class     = try(f.storage_class, null)
      redundancy_type   = try(f.redundancy_type, null)
      visibility        = try(f.visibility, null)
      ram_user_id       = dependency.ram.outputs.instances[f.ram_user].user_id
      versioning        = try(f.versioning, null)
      sse_algorithm     = try(f.sse_algorithm, null)
      kms_master_key_id = can(f.kms_key) ? dependency.kms.outputs.instances[f.kms_key].key_id : try(f.kms_master_key_id, null)
      lifecycle_rules   = try(f.lifecycle_rules, null)
      force_destroy     = try(f.force_destroy, null)
      tags              = try(f.tags, {})
    }
  }

  tags = include.root.locals.base_tags
}
