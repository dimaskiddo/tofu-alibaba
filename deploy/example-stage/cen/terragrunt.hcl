include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "description", "cen_id", "attachments", "peer_attachments", "remote_attachment_ids",
  ]
  attachment_known = ["vpc", "vswitches", "description"]
  unknown = concat(
    [
      for n, f in include.root.locals.instances : "instance ${n}: unknown key(s) ${join(", ", sort(setsubtract(keys(f), local.known)))}"
      if length(setsubtract(keys(f), local.known)) > 0
    ],
    flatten([
      for n, f in include.root.locals.instances : [
        for an, a in try(f.attachments, {}) : "instance ${n} attachment ${an}: unknown key(s) ${join(", ", sort(setsubtract(keys(a), local.attachment_known)))}"
        if length(setsubtract(keys(a), local.attachment_known)) > 0
      ]
    ]),
  )
  keys_ok = lookup({ ok = "ok" }, length(local.unknown) == 0 ? "ok" : join("; ", local.unknown))
  members = { for n, f in include.root.locals.instances : n => f if local.keys_ok == "ok" }
  atts    = merge([for f in values(local.members) : try(f.attachments, {})]...)
  vpcs    = distinct([for a in values(local.atts) : a.vpc])
  zones   = include.root.locals.provider_cfg.zones
  subnets = distinct(flatten([for a in values(local.atts) : a.vswitches]))
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    instances = { for v in local.vpcs : v => { vpc_id = "vpc-mock" } }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "subnet" {
  config_path = "../subnet"

  mock_outputs = {
    groups = {
      for v in local.vpcs : v => {
        subnet_ids = { for s in local.subnets : s => "vsw-mock" }
      }
    }
    subnet_zones = { for i, s in local.subnets : s => local.zones[i % length(local.zones)] }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

terraform {
  source = "${include.root.locals.modules_dir}//cen/instances"
}

inputs = {
  zones = local.zones

  instances = {
    for n, f in local.members : n => {
      cen_id                = try(f.cen_id, null)
      description           = try(f.description, null)
      peer_attachments      = try(f.peer_attachments, {})
      remote_attachment_ids = try(f.remote_attachment_ids, {})

      # A vSwitch is looked up under its own VPC's group, so one from another VPC fails the lookup.
      vpc_attachments = {
        for an, a in try(f.attachments, {}) : an => {
          vpc_id = dependency.vpc.outputs.instances[a.vpc].vpc_id
          zone_mappings = [
            for s in a.vswitches : {
              vswitch_id = dependency.subnet.outputs.groups[a.vpc].subnet_ids[s]
              zone_id    = dependency.subnet.outputs.subnet_zones[s]
            }
          ]
          description = try(a.description, null)
        }
      }

      tags = try(f.tags, {})
    }
  }

  tags = include.root.locals.base_tags
}
