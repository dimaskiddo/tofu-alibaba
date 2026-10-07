include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "group", "cidr_block", "zone_id",
  ]
  unknown = [
    for n, f in include.root.locals.instances : "instance ${n}: unknown key(s) ${join(", ", sort(setsubtract(keys(f), local.known)))}"
    if length(setsubtract(keys(f), local.known)) > 0
  ]
  keys_ok = lookup({ ok = "ok" }, length(local.unknown) == 0 ? "ok" : join("; ", local.unknown))
  members = { for n, f in include.root.locals.instances : n => f if local.keys_ok == "ok" }
  groups  = distinct([for f in values(local.members) : f.group])
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    instances = {
      for g in local.groups : g => {
        vpc_id     = "vpc-mock"
        cidr_block = include.root.locals.mock.any_cidr
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

terraform {
  source = "${include.root.locals.modules_dir}//subnet/instances"
}

inputs = {
  groups = {
    for g in local.groups : g => {
      vpc_id         = dependency.vpc.outputs.instances[g].vpc_id
      vpc_cidr_block = dependency.vpc.outputs.instances[g].cidr_block
      subnets = [
        for n, f in local.members : {
          name       = n
          cidr_block = f.cidr_block
          zone_id    = f.zone_id
          tags       = try(f.tags, {})
        } if f.group == g
      ]
    }
  }

  tags = include.root.locals.base_tags
}
