include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "bandwidth", "internet_charge_type", "isp", "description",
    "deletion_protection", "eips", "albs",
  ]
  unknown = [
    for n, f in include.root.locals.instances : "instance ${n}: unknown key(s) ${join(", ", sort(setsubtract(keys(f), local.known)))}"
    if length(setsubtract(keys(f), local.known)) > 0
  ]
  keys_ok = lookup({ ok = "ok" }, length(local.unknown) == 0 ? "ok" : join("; ", local.unknown))
  members = { for n, f in include.root.locals.instances : n => f if local.keys_ok == "ok" }
  eips    = flatten([for f in values(local.members) : try(f.eips, [])])
  albs    = flatten([for f in values(local.members) : try(f.albs, [])])

  # One IP or ALB belongs to one package.
  shared = concat(
    [for e in distinct(local.eips) : "eip ${e}" if length([for x in local.eips : x if x == e]) > 1],
    [for a in distinct(local.albs) : "alb ${a}" if length([for x in local.albs : x if x == a]) > 1],
  )
  shared_ok = lookup({ ok = "ok" }, length(local.shared) == 0 ? "ok" : "listed in more than one package: ${join(", ", local.shared)}")
}

dependency "eip" {
  config_path = "../eip"
  enabled     = length(local.eips) > 0

  mock_outputs = {
    eip_ids = { for e in local.eips : e => "eip-mock" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "alb" {
  config_path = "../slb/alb"
  enabled     = length(local.albs) > 0

  mock_outputs = {
    instances = { for a in local.albs : a => { load_balancer_id = "alb-mock" } }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

terraform {
  source = "${include.root.locals.modules_dir}//cbwp/instances"
}

inputs = {
  instances = {
    for n, f in local.members : n => {
      bandwidth            = f.bandwidth
      internet_charge_type = try(f.internet_charge_type, null)
      isp                  = try(f.isp, null)
      description          = try(f.description, null)
      deletion_protection  = try(f.deletion_protection, null)
      eip_ids              = { for e in try(f.eips, []) : e => dependency.eip.outputs.eip_ids[e] if local.shared_ok == "ok" }
      alb_ids              = { for a in try(f.albs, []) : a => dependency.alb.outputs.instances[a].load_balancer_id if local.shared_ok == "ok" }
      tags                 = try(f.tags, {})
    }
  }

  tags = include.root.locals.base_tags
}
