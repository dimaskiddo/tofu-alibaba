include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "vpc", "engine", "engine_version", "category",
    "instance_type", "instance_storage", "db_instance_storage_type", "placement", "security_ips", "deletion_protection",
    "maintain_time", "parameters", "storage_auto_scale", "backup", "databases", "accounts",
    "password_length", "kms_key", "role_arn",
  ]
  unknown = [
    for n, f in include.root.locals.instances : "instance ${n}: unknown key(s) ${join(", ", sort(setsubtract(keys(f), local.known)))}"
    if length(setsubtract(keys(f), local.known)) > 0
  ]
  keys_ok  = lookup({ ok = "ok" }, length(local.unknown) == 0 ? "ok" : join("; ", local.unknown))
  members  = { for n, f in include.root.locals.instances : n => f if local.keys_ok == "ok" }
  kms_keys = distinct([for f in values(local.members) : f.kms_key if can(f.kms_key)])
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

dependency "kms" {
  config_path = "../kms"
  enabled     = length(local.kms_keys) > 0

  mock_outputs = {
    instances = { for k in local.kms_keys : k => { key_id = "key-mock" } }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

terraform {
  source = "${include.root.locals.modules_dir}//rds/instances"
}

# Account passwords may come from <TENANT>_<ENV>_RDS_ACCOUNT_PASSWORDS, shaped { "<instance>" = { "<account>" = "<password>" } };
# an account without an entry gets a random password (output generated_passwords).
inputs = {
  instances = {
    for n, f in local.members : n => {
      engine                   = f.engine
      engine_version           = f.engine_version
      category                 = f.category
      instance_type            = f.instance_type
      instance_storage         = f.instance_storage
      db_instance_storage_type = try(f.db_instance_storage_type, null)
      placement                = [for p in f.placement : { zone_id = lookup({ ok = p.zone_id }, dependency.subnet.outputs.subnet_zones[p.subnet] == p.zone_id ? "ok" : "instance ${n}: zone_id ${p.zone_id} is not the zone of subnet ${p.subnet} (${dependency.subnet.outputs.subnet_zones[p.subnet]})"), vswitch_id = dependency.subnet.outputs.subnet_ids[p.subnet] }]
      security_ips             = try(f.security_ips, [dependency.vpc.outputs.instances[f.vpc].cidr_block])
      deletion_protection      = try(f.deletion_protection, null)
      maintain_time            = try(f.maintain_time, null)
      parameters               = try(f.parameters, null)
      storage_auto_scale       = try(f.storage_auto_scale, null)
      backup                   = try(f.backup, null)
      databases                = try(f.databases, null)
      accounts                 = try(f.accounts, null)
      password_length          = try(f.password_length, null)
      role_arn                 = try(f.role_arn, null)
      encryption_key           = can(f.kms_key) ? dependency.kms.outputs.instances[f.kms_key].key_id : null
      tags                     = try(f.tags, {})
    }
  }

  tags = include.root.locals.base_tags
}
