include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "vpc", "description", "rules", "inner_access_policy",
  ]
  unknown = [
    for n, f in include.root.locals.instances : "instance ${n}: unknown key(s) ${join(", ", sort(setsubtract(keys(f), local.known)))}"
    if length(setsubtract(keys(f), local.known)) > 0
  ]
  keys_ok   = lookup({ ok = "ok" }, length(local.unknown) == 0 ? "ok" : join("; ", local.unknown))
  rule_keys = ["name", "type", "ip_protocol", "port_range", "cidr_ip", "source_security_group_id", "policy", "priority", "description"]
  rules_ok  = lookup({ ok = "ok" }, length(local.rule_unknown) == 0 ? "ok" : join("; ", local.rule_unknown))
  rule_unknown = flatten([
    for n, f in include.root.locals.instances : [
      for r in try(f.rules, []) : "instance ${n}: unknown rule key(s) ${join(", ", sort(setsubtract(keys(r), local.rule_keys)))} in rule ${try(r.name, "?")}"
      if length(setsubtract(keys(r), local.rule_keys)) > 0
    ]
  ])
  members = { for n, f in include.root.locals.instances : n => f if local.keys_ok == "ok" && local.rules_ok == "ok" }
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    instances = {
      for v in distinct([for f in values(local.members) : f.vpc]) : v => {
        vpc_id     = "vpc-mock"
        cidr_block = include.root.locals.mock.vpc_cidr
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

terraform {
  source = "${include.root.locals.modules_dir}//security-group/instances"
}

inputs = {
  instances = {
    for n, f in local.members : n => {
      vpc_id              = dependency.vpc.outputs.instances[f.vpc].vpc_id
      description         = try(f.description, null)
      inner_access_policy = try(f.inner_access_policy, null)
      rules = [
        for r in try(f.rules, []) :
        contains(keys(r), "cidr_ip") || contains(keys(r), "source_security_group_id") ? r : merge(r, { cidr_ip = dependency.vpc.outputs.instances[f.vpc].cidr_block })
      ]
      tags = try(f.tags, {})
    }
  }

  tags = include.root.locals.base_tags
}
