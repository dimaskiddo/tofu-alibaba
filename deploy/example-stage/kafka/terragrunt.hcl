include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "vpc", "partition_num", "disk_type", "disk_size", "io_max_spec", "spec_type",
    "service_version", "placement", "security_group", "allowed_ips", "topics", "consumer_groups", "sasl_users", "password_length",
  ]
  unknown = [
    for n, f in include.root.locals.instances : "instance ${n}: unknown key(s) ${join(", ", sort(setsubtract(keys(f), local.known)))}"
    if length(setsubtract(keys(f), local.known)) > 0
  ]
  keys_ok         = lookup({ ok = "ok" }, length(local.unknown) == 0 ? "ok" : join("; ", local.unknown))
  members         = { for n, f in include.root.locals.instances : n => f if local.keys_ok == "ok" }
  security_groups = distinct([for f in values(local.members) : f.security_group if can(f.security_group)])
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    instances = {
      for v in distinct([for f in values(local.members) : f.vpc]) : v => {
        cidr_block = include.root.locals.mock.vpc_cidr
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "subnet" {
  config_path = "../subnet"

  mock_outputs = {
    subnet_ids   = { for s in distinct(flatten([for f in values(local.members) : [for p in f.placement : p.subnet]])) : s => "vsw-mock" }
    subnet_zones = merge(flatten([for f in values(local.members) : [for p in f.placement : { (p.subnet) = p.zone_id }]])...)
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "security_group" {
  config_path = "../security-group"
  enabled     = length(local.security_groups) > 0

  mock_outputs = {
    instances = { for g in local.security_groups : g => { security_group_id = "sg-mock" } }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

terraform {
  source = "${include.root.locals.modules_dir}//kafka/instances"
}

# SASL passwords may come from <TENANT>_<ENV>_KAFKA_SASL_PASSWORDS, shaped { "<instance>" = { "<user>" = "<password>" } };
# a user without an entry gets a random password (output generated_passwords).
inputs = {
  instances = {
    for n, f in local.members : n => {
      partition_num     = f.partition_num
      disk_type         = f.disk_type
      disk_size         = f.disk_size
      io_max_spec       = f.io_max_spec
      spec_type         = try(f.spec_type, null)
      service_version   = try(f.service_version, null)
      placement         = [for p in f.placement : { zone_id = lookup({ ok = p.zone_id }, dependency.subnet.outputs.subnet_zones[p.subnet] == p.zone_id ? "ok" : "instance ${n}: zone_id ${p.zone_id} is not the zone of subnet ${p.subnet} (${dependency.subnet.outputs.subnet_zones[p.subnet]})"), vswitch_id = dependency.subnet.outputs.subnet_ids[p.subnet] }]
      security_group_id = can(f.security_group) ? dependency.security_group.outputs.instances[f.security_group].security_group_id : null
      allowed_ips       = try(f.allowed_ips, [dependency.vpc.outputs.instances[f.vpc].cidr_block])
      topics            = try(f.topics, null)
      consumer_groups   = try(f.consumer_groups, null)
      sasl_users        = try(f.sasl_users, null)
      password_length   = try(f.password_length, null)
      tags              = try(f.tags, {})
    }
  }

  tags = include.root.locals.base_tags
}
