include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "nat", "eip", "transit_ip", "sources",
  ]
  unknown = [
    for n, f in include.root.locals.instances : "instance ${n}: unknown key(s) ${join(", ", sort(setsubtract(keys(f), local.known)))}"
    if length(setsubtract(keys(f), local.known)) > 0
  ]
  keys_ok    = lookup({ ok = "ok" }, length(local.unknown) == 0 ? "ok" : join("; ", local.unknown))
  no_address = [for n, f in include.root.locals.instances : "instance ${n}: set eip or transit_ip" if !can(f.eip) && !can(f.transit_ip)]
  address_ok = lookup({ ok = "ok" }, length(local.no_address) == 0 ? "ok" : join("; ", local.no_address))
  members    = { for n, f in include.root.locals.instances : n => f if local.keys_ok == "ok" && local.address_ok == "ok" }
  eips       = distinct([for f in values(local.members) : f.eip if can(f.eip)])
}

dependency "nat" {
  config_path = "../"

  mock_outputs = {
    instances = {
      for nn in distinct([for f in values(local.members) : f.nat]) : nn => {
        snat_table_ids    = "stb-mock"
        forward_table_ids = "ftb-mock"
        nat_ips           = { for g in values(local.members) : g.transit_ip => "10.255.255.10" if can(g.transit_ip) && g.nat == nn }
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "subnet" {
  config_path = "../../subnet"

  mock_outputs = {
    subnet_ids = { for s in distinct(flatten([for f in values(local.members) : f.sources])) : s => "vsw-mock" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "eip" {
  config_path = "../../eip"
  enabled     = length(local.eips) > 0

  mock_outputs = {
    eip_addresses = { for e in local.eips : e => "203.0.113.10" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

terraform {
  source = "${include.root.locals.modules_dir}//nat-snat/instances"
}

inputs = {
  instances = {
    for n, f in local.members : n => {
      snat_table_id = dependency.nat.outputs.instances[f.nat].snat_table_ids
      snat_ips      = [can(f.eip) ? dependency.eip.outputs.eip_addresses[f.eip] : dependency.nat.outputs.instances[f.nat].nat_ips[f.transit_ip]]

      entries = [
        for s in f.sources : {
          name              = "snat-${s}"
          source_vswitch_id = dependency.subnet.outputs.subnet_ids[s]
        }
      ]

      tags = try(f.tags, {})
    }
  }

  tags = include.root.locals.base_tags
}
