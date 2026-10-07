include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "vpc", "accepting_vpc", "accepting_vpc_id", "accepting_vpc_cidr_block", "accepting_region_id", "accepting_ali_uid",
    "bandwidth", "link_type", "description", "routes",
  ]
  unknown = [
    for n, f in include.root.locals.instances : "instance ${n}: unknown key(s) ${join(", ", sort(setsubtract(keys(f), local.known)))}"
    if length(setsubtract(keys(f), local.known)) > 0
  ]
  keys_ok = lookup({ ok = "ok" }, length(local.unknown) == 0 ? "ok" : join("; ", local.unknown))
  region  = include.root.locals.provider_cfg.region

  # An accepter in another region is not in this tenant's region, so it is given as literal ID and CIDR, not by name.
  inter = { for n, f in include.root.locals.instances : n => try(f.accepting_region_id, local.region) != local.region }
  accepter_errors = [
    for n, f in include.root.locals.instances : local.inter[n] ?
    (can(f.accepting_vpc_id) && can(f.accepting_vpc_cidr_block) && !can(f.accepting_vpc) ? "" : "instance ${n}: an inter-region peering needs accepting_vpc_id and accepting_vpc_cidr_block, and no accepting_vpc") :
    (can(f.accepting_vpc) && !can(f.accepting_vpc_id) && !can(f.accepting_vpc_cidr_block) ? "" : "instance ${n}: a same-region peering needs accepting_vpc (a name), not accepting_vpc_id or accepting_vpc_cidr_block")
  ]
  accepter_failed = [for e in local.accepter_errors : e if e != ""]
  accepter_ok     = lookup({ ok = "ok" }, length(local.accepter_failed) == 0 ? "ok" : join("; ", local.accepter_failed))
  members         = { for n, f in include.root.locals.instances : n => f if local.keys_ok == "ok" && local.accepter_ok == "ok" }
  vpcs            = distinct(flatten([for n, f in local.members : concat([f.vpc], local.inter[n] ? [] : [f.accepting_vpc])]))
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    instances = {
      for i, v in local.vpcs : v => {
        vpc_id         = "vpc-mock-${i}"
        cidr_block     = cidrsubnet(include.root.locals.mock.any_cidr, 8, i + 1)
        route_table_id = "vtb-mock-${i}"
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

terraform {
  source = "${include.root.locals.modules_dir}//vpc-peering/instances"
}

inputs = {
  instances = {
    for n, f in local.members : n => {
      vpc_id                   = dependency.vpc.outputs.instances[f.vpc].vpc_id
      vpc_cidr_block           = dependency.vpc.outputs.instances[f.vpc].cidr_block
      accepting_vpc_id         = local.inter[n] ? f.accepting_vpc_id : dependency.vpc.outputs.instances[f.accepting_vpc].vpc_id
      accepting_vpc_cidr_block = local.inter[n] ? f.accepting_vpc_cidr_block : dependency.vpc.outputs.instances[f.accepting_vpc].cidr_block
      accepting_region_id      = try(f.accepting_region_id, local.region)
      accepting_ali_uid        = try(f.accepting_ali_uid, null)
      bandwidth                = try(f.bandwidth, null)
      link_type                = try(f.link_type, null)
      description              = try(f.description, null)

      # The provider is single-region: the accepter route table is only reachable inside the same region.
      route_table_id           = try(f.routes, true) ? dependency.vpc.outputs.instances[f.vpc].route_table_id : null
      accepting_route_table_id = try(f.routes, true) && !local.inter[n] ? dependency.vpc.outputs.instances[f.accepting_vpc].route_table_id : null

      tags = try(f.tags, {})
    }
  }

  tags = include.root.locals.base_tags
}
