include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "vpc", "address_type", "load_balancer_edition", "zone_mappings",
    "server_groups", "listeners", "rules",
  ]
  unknown = [
    for n, f in include.root.locals.instances : "instance ${n}: unknown key(s) ${join(", ", sort(setsubtract(keys(f), local.known)))}"
    if length(setsubtract(keys(f), local.known)) > 0
  ]
  keys_ok = lookup({ ok = "ok" }, length(local.unknown) == 0 ? "ok" : join("; ", local.unknown))
  members = { for n, f in include.root.locals.instances : n => f if local.keys_ok == "ok" }
  refs    = distinct(flatten([for f in values(local.members) : [for g in values(f.server_groups) : [for s in try(g.servers, []) : s.instance]]]))
}

dependency "vpc" {
  config_path = "../../vpc"

  mock_outputs = {
    instances = { for v in distinct([for f in values(local.members) : f.vpc]) : v => { vpc_id = "vpc-mock" } }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "subnet" {
  config_path = "../../subnet"

  mock_outputs = {
    subnet_ids   = { for s in distinct(flatten([for f in values(local.members) : [for z in f.zone_mappings : z.subnet]])) : s => "vsw-mock" }
    subnet_zones = merge(flatten([for f in values(local.members) : [for z in f.zone_mappings : { (z.subnet) = z.zone_id }]])...)
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "ecs" {
  config_path = "../../ecs"

  mock_outputs = {
    instance_ids = { for r in local.refs : r => "i-mock" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

terraform {
  source = "${include.root.locals.modules_dir}//slb-alb/instances"
}

inputs = {
  instances = {
    for n, f in local.members : n => {
      vpc_id                = dependency.vpc.outputs.instances[f.vpc].vpc_id
      address_type          = f.address_type
      load_balancer_edition = f.load_balancer_edition

      zone_mappings = [
        for z in f.zone_mappings : {
          zone_id    = lookup({ ok = z.zone_id }, dependency.subnet.outputs.subnet_zones[z.subnet] == z.zone_id ? "ok" : "instance ${n}: zone_id ${z.zone_id} is not the zone of subnet ${z.subnet} (${dependency.subnet.outputs.subnet_zones[z.subnet]})")
          vswitch_id = dependency.subnet.outputs.subnet_ids[z.subnet]
        }
      ]

      server_groups = {
        for gn, g in f.server_groups : gn => merge(g, {
          servers = [
            for s in try(g.servers, []) : merge(
              { for a, v in s : a => v if a != "instance" },
              { server_id = dependency.ecs.outputs.instance_ids[s.instance] },
            )
          ]
        })
      }

      listeners = f.listeners
      rules     = try(f.rules, null)
      tags      = try(f.tags, {})
    }
  }

  tags = include.root.locals.base_tags
}
