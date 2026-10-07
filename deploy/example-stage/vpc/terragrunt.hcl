include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "cidr_block", "description",
  ]
  unknown = [
    for n, f in include.root.locals.instances : "instance ${n}: unknown key(s) ${join(", ", sort(setsubtract(keys(f), local.known)))}"
    if length(setsubtract(keys(f), local.known)) > 0
  ]
  keys_ok = lookup({ ok = "ok" }, length(local.unknown) == 0 ? "ok" : join("; ", local.unknown))
  members = { for n, f in include.root.locals.instances : n => f if local.keys_ok == "ok" }
}

terraform {
  source = "${include.root.locals.modules_dir}//vpc/instances"
}

inputs = {
  instances = {
    for n, f in local.members : n => {
      cidr_block  = f.cidr_block
      description = try(f.description, null)
      tags        = try(f.tags, {})
    }
  }

  tags = include.root.locals.base_tags
}
