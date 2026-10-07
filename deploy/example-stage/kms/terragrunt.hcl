include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "dkms_instance_id", "description", "key_spec", "rotation_interval",
    "pending_window_in_days", "deletion_protection",
  ]
  unknown = [
    for n, f in include.root.locals.instances : "instance ${n}: unknown key(s) ${join(", ", sort(setsubtract(keys(f), local.known)))}"
    if length(setsubtract(keys(f), local.known)) > 0
  ]
  keys_ok = lookup({ ok = "ok" }, length(local.unknown) == 0 ? "ok" : join("; ", local.unknown))
  members = { for n, f in include.root.locals.instances : n => f if local.keys_ok == "ok" }
}

terraform {
  source = "${include.root.locals.modules_dir}//kms/instances"
}

inputs = {
  instances = {
    for n, f in local.members : n => {
      dkms_instance_id       = try(f.dkms_instance_id, include.root.locals.tenant_env.kms_instance_id)
      description            = try(f.description, null)
      key_spec               = try(f.key_spec, null)
      rotation_interval      = try(f.rotation_interval, "365d")
      pending_window_in_days = try(f.pending_window_in_days, null)
      deletion_protection    = try(f.deletion_protection, null)
      tags                   = try(f.tags, {})
    }
  }

  tags = include.root.locals.base_tags
}
