include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "address_type", "subnet", "internet_charge_type", "bandwidth",
    "master_zone_id", "slave_zone_id", "load_balancer_spec", "backend_servers", "listeners",
  ]
  unknown = [
    for n, f in include.root.locals.instances : "instance ${n}: unknown key(s) ${join(", ", sort(setsubtract(keys(f), local.known)))}"
    if length(setsubtract(keys(f), local.known)) > 0
  ]
  keys_ok = lookup({ ok = "ok" }, length(local.unknown) == 0 ? "ok" : join("; ", local.unknown))
  members = { for n, f in include.root.locals.instances : n => f if local.keys_ok == "ok" }
  refs    = distinct(flatten([for f in values(local.members) : [for b in values(try(f.backend_servers, {})) : b.instance]]))
}

dependency "subnet" {
  config_path = "../../subnet"

  mock_outputs = {
    subnet_ids   = { for s in distinct([for f in values(local.members) : f.subnet if can(f.subnet)]) : s => "vsw-mock" }
    subnet_zones = merge([for f in values(local.members) : { (f.subnet) = try(f.master_zone_id, "zone-mock") } if can(f.subnet)]...)
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
  source = "${include.root.locals.modules_dir}//slb-clb/instances"
}

inputs = {
  instances = {
    for n, f in local.members : n => {
      address_type         = f.address_type
      vswitch_id           = can(f.subnet) ? dependency.subnet.outputs.subnet_ids[f.subnet] : null
      master_zone_id       = !can(f.master_zone_id) || !can(f.subnet) ? try(f.master_zone_id, null) : lookup({ ok = f.master_zone_id }, dependency.subnet.outputs.subnet_zones[f.subnet] == f.master_zone_id ? "ok" : "instance ${n}: master_zone_id ${f.master_zone_id} is not the zone of subnet ${f.subnet} (${dependency.subnet.outputs.subnet_zones[f.subnet]})")
      slave_zone_id        = try(f.slave_zone_id, null)
      load_balancer_spec   = try(f.load_balancer_spec, null)
      internet_charge_type = try(f.internet_charge_type, null)
      bandwidth            = try(f.bandwidth, null)
      backend_servers = {
        for k, b in try(f.backend_servers, {}) : k => merge(
          { for a, v in b : a => v if a != "instance" },
          { server_id = dependency.ecs.outputs.instance_ids[b.instance] },
        )
      }
      listeners = f.listeners
      tags      = try(f.tags, {})
    }
  }

  tags = include.root.locals.base_tags
}
