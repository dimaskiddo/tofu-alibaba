include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "vpc", "custom", "description", "vswitches",
    "routes",
  ]
  unknown = [
    for n, f in include.root.locals.instances : "instance ${n}: unknown key(s) ${join(", ", sort(setsubtract(keys(f), local.known)))}"
    if length(setsubtract(keys(f), local.known)) > 0
  ]
  keys_ok   = lookup({ ok = "ok" }, length(local.unknown) == 0 ? "ok" : join("; ", local.unknown))
  members   = { for n, f in include.root.locals.instances : n => f if local.keys_ok == "ok" }
  routes    = flatten([for f in values(local.members) : values(f.routes)])
  vswitches = distinct(flatten([for f in values(local.members) : try(f.vswitches, [])]))
  peers     = distinct([for r in local.routes : r.nexthop if try(r.nexthop_type, "") == "VpcPeer" && can(r.nexthop)])
  nats      = distinct([for r in local.routes : r.nexthop if try(r.nexthop_type, "") == "NatGateway" && can(r.nexthop)])
  cens      = distinct([for r in local.routes : r.nexthop if try(r.nexthop_type, "") == "Attachment" && can(r.nexthop)])
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    instances = {
      for v in distinct([for f in values(local.members) : f.vpc]) : v => {
        vpc_id         = "vpc-mock"
        route_table_id = "vtb-mock"
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "subnet" {
  config_path = "../subnet"
  enabled     = length(local.vswitches) > 0

  mock_outputs = {
    subnet_ids = { for s in local.vswitches : s => "vsw-mock" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "vpc_peering" {
  config_path = "../vpc-peering"
  enabled     = length(local.peers) > 0

  mock_outputs = {
    instances = { for p in local.peers : p => { peer_connection_id = "pcc-mock" } }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "nat" {
  config_path = "../nat"
  enabled     = length(local.nats) > 0

  mock_outputs = {
    instances = { for n in local.nats : n => { nat_gateway_id = "ngw-mock" } }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "cen" {
  config_path = "../cen"
  enabled     = length(local.cens) > 0

  mock_outputs = {
    attachment_ids = { for a in local.cens : a => "tr-attach-mock" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

terraform {
  source = "${include.root.locals.modules_dir}//route-table/instances"
}

inputs = {
  instances = {
    for n, f in local.members : n => {
      route_table_id   = try(f.custom, false) ? null : dependency.vpc.outputs.instances[f.vpc].route_table_id
      vpc_id           = try(f.custom, false) ? dependency.vpc.outputs.instances[f.vpc].vpc_id : null
      route_table_name = try(f.custom, false) ? n : null
      description      = try(f.description, null)
      vswitch_ids      = { for s in try(f.vswitches, []) : s => dependency.subnet.outputs.subnet_ids[s] }

      routes = {
        for rn, r in f.routes : rn => {
          destination_cidrblock = r.destination_cidrblock
          nexthop_type          = r.nexthop_type
          nexthop_id = try(r.nexthop_id, r.nexthop_type == "VpcPeer" ? dependency.vpc_peering.outputs.instances[r.nexthop].peer_connection_id : (
            r.nexthop_type == "NatGateway" ? dependency.nat.outputs.instances[r.nexthop].nat_gateway_id : (
              r.nexthop_type == "Attachment" ? dependency.cen.outputs.attachment_ids[r.nexthop] :
              lookup({ ok = "ok" }, "route ${rn} of ${n}: nexthop_type ${r.nexthop_type} needs a literal nexthop_id; nexthop names resolve only VpcPeer, NatGateway and Attachment")
            )
          ))
          description = try(r.description, null)
        }
      }

      tags = try(f.tags, {})
    }
  }

  tags = include.root.locals.base_tags
}
