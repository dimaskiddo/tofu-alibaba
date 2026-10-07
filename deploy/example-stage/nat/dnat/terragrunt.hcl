include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "nat", "eip", "transit_ip", "backend",
    "mappings",
  ]
  unknown = [
    for n, f in include.root.locals.instances : "instance ${n}: unknown key(s) ${join(", ", sort(setsubtract(keys(f), local.known)))}"
    if length(setsubtract(keys(f), local.known)) > 0
  ]
  keys_ok = lookup({ ok = "ok" }, length(local.unknown) == 0 ? "ok" : join("; ", local.unknown))
  # A missing address would otherwise surface as an opaque index error deep in inputs.
  no_address = [for n, f in include.root.locals.instances : "instance ${n}: set eip or transit_ip" if !can(f.eip) && !can(f.transit_ip)]
  address_ok = lookup({ ok = "ok" }, length(local.no_address) == 0 ? "ok" : join("; ", local.no_address))
  members    = { for n, f in include.root.locals.instances : n => f if local.keys_ok == "ok" && local.address_ok == "ok" }
  eips       = distinct([for f in values(local.members) : f.eip if can(f.eip)])

  snat_files = fileset("${get_terragrunt_dir()}/../snat", "*.hcl")
  snat = {
    for f in local.snat_files : read_terragrunt_config("${get_terragrunt_dir()}/../snat/${f}").locals.name => read_terragrunt_config("${get_terragrunt_dir()}/../snat/${f}").locals
    if f != "terragrunt.hcl" && substr(f, 0, 1) != "."
  }

  # Inbound DNAT and outbound SNAT on one NAT must not share an address: an any-port DNAT address cannot be shared.
  conflicts = flatten([
    for n, d in local.members : [
      for sn, s in local.snat : "${n} and ${sn} both use ${try(d.eip, d.transit_ip)} on ${d.nat}"
      if s.nat == d.nat && try(s.eip, s.transit_ip) == try(d.eip, d.transit_ip)
    ]
  ])
  addresses_distinct = lookup({ ok = "ok" }, length(local.conflicts) == 0 ? "ok" : "DNAT and SNAT must use different addresses: ${join("; ", local.conflicts)}")
}

dependency "nat" {
  config_path = "../"

  mock_outputs = {
    instances = {
      for nn in distinct([for f in values(local.members) : f.nat]) : nn => {
        snat_table_ids    = "stb-mock"
        forward_table_ids = "ftb-mock"
        nat_ips           = { for g in values(local.members) : g.transit_ip => "10.255.255.20" if can(g.transit_ip) && g.nat == nn }
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "eip" {
  config_path = "../../eip"
  enabled     = length(local.eips) > 0

  mock_outputs = {
    eip_addresses = { for e in local.eips : e => "203.0.113.11" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "ecs" {
  config_path = "../../ecs"

  mock_outputs = {
    private_ips = { for b in distinct([for f in values(local.members) : f.backend]) : b => "10.0.0.1" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

terraform {
  source = "${include.root.locals.modules_dir}//nat-dnat/instances"
}

inputs = {
  instances = {
    for n, f in local.members : n => {
      forward_table_id = dependency.nat.outputs.instances[f.nat].forward_table_ids

      entries = [
        for m in f.mappings : {
          name          = m.name
          external_ip   = can(f.eip) ? dependency.eip.outputs.eip_addresses[f.eip] : dependency.nat.outputs.instances[f.nat].nat_ips[f.transit_ip]
          external_port = m.external_port
          internal_ip   = dependency.ecs.outputs.private_ips[f.backend]
          internal_port = m.internal_port
          ip_protocol   = try(m.ip_protocol, "tcp")
        }
      ]

      tags = try(f.tags, {})
    }
  }

  tags = include.root.locals.base_tags
}
