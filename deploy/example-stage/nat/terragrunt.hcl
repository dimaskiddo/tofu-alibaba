include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "network_type", "vpc", "subnet", "description",
    "eips", "transit_cidr", "transit_ips",
  ]
  unknown = [
    for n, f in include.root.locals.instances : "instance ${n}: unknown key(s) ${join(", ", sort(setsubtract(keys(f), local.known)))}"
    if length(setsubtract(keys(f), local.known)) > 0
  ]
  keys_ok = lookup({ ok = "ok" }, length(local.unknown) == 0 ? "ok" : join("; ", local.unknown))
  members = { for n, f in include.root.locals.instances : n => f if local.keys_ok == "ok" }
  eips    = distinct(flatten([for f in values(local.members) : try(f.eips, [])]))
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    instances = {
      for v in distinct([for f in values(local.members) : f.vpc]) : v => {
        vpc_id         = "vpc-mock"
        cidr_block     = include.root.locals.mock.vpc_cidr
        route_table_id = "vtb-mock"
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "subnet" {
  config_path = "../subnet"

  mock_outputs = {
    subnet_ids = { for s in distinct([for f in values(local.members) : f.subnet]) : s => "vsw-mock" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "eip" {
  config_path = "../eip"
  enabled     = length(local.eips) > 0

  mock_outputs = {
    eip_ids = { for e in local.eips : e => "eip-mock" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

terraform {
  source = "${include.root.locals.modules_dir}//nat/instances"
}

inputs = {
  instances = {
    for n, f in local.members : n => {
      network_type       = f.network_type
      vpc_id             = dependency.vpc.outputs.instances[f.vpc].vpc_id
      vswitch_id         = dependency.subnet.outputs.subnet_ids[f.subnet]
      description        = try(f.description, null)
      eip_allocation_ids = { for e in try(f.eips, []) : e => dependency.eip.outputs.eip_ids[e] }
      vpc_cidr_block     = f.network_type == "intranet" ? dependency.vpc.outputs.instances[f.vpc].cidr_block : null
      route_table_id     = f.network_type == "intranet" ? dependency.vpc.outputs.instances[f.vpc].route_table_id : null
      nat_ip_cidr        = try(f.transit_cidr, null)
      nat_ips            = try(f.transit_ips, null)
      tags               = try(f.tags, {})
    }
  }

  tags = include.root.locals.base_tags
}
