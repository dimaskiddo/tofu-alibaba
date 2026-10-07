include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "vpc", "subnet", "architecture", "engine_version", "instance_class", "storage_gb", "replication_factor", "readonly_replicas",
    "mongos", "shards", "config_server", "storage_type", "zone_id", "secondary_zone_id", "hidden_zone_id", "security_ips", "deletion_protection",
    "backup", "parameters", "password_length", "kms_key",
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
        vpc_id     = "vpc-mock"
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "subnet" {
  config_path = "../subnet"

  mock_outputs = {
    subnet_ids   = { for s in distinct([for f in values(local.members) : f.subnet]) : s => "vsw-mock" }
    subnet_zones = merge([for f in values(local.members) : { (f.subnet) = f.zone_id }]...)
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
  source = "${include.root.locals.modules_dir}//mongodb/instances"
}

# The root password may come from <TENANT>_<ENV>_MONGODB_PASSWORDS, shaped { "<instance>" = "<password>" };
# an instance without an entry gets a random password (output generated_passwords).
inputs = {
  instances = {
    for n, f in local.members : n => {
      architecture           = f.architecture
      engine_version         = f.engine_version
      instance_class         = try(f.instance_class, null)
      storage_gb             = try(f.storage_gb, null)
      replication_factor     = try(f.replication_factor, null)
      readonly_replicas      = try(f.readonly_replicas, null)
      mongos                 = try(f.mongos, [])
      shards                 = try(f.shards, [])
      config_server          = try(f.config_server, null)
      storage_type           = try(f.storage_type, null)
      vpc_id                 = dependency.vpc.outputs.instances[f.vpc].vpc_id
      vswitch_id             = dependency.subnet.outputs.subnet_ids[f.subnet]
      zone_id                = lookup({ ok = f.zone_id }, dependency.subnet.outputs.subnet_zones[f.subnet] == f.zone_id ? "ok" : "instance ${n}: zone_id ${f.zone_id} is not the zone of subnet ${f.subnet} (${dependency.subnet.outputs.subnet_zones[f.subnet]})")
      secondary_zone_id      = try(f.secondary_zone_id, null)
      hidden_zone_id         = try(f.hidden_zone_id, null)
      security_ips           = try(f.security_ips, [dependency.vpc.outputs.instances[f.vpc].cidr_block])
      deletion_protection    = try(f.deletion_protection, null)
      backup                 = try(f.backup, null)
      parameters             = try(f.parameters, {})
      password_length        = try(f.password_length, null)
      disk_encryption_key_id = can(f.kms_key) ? dependency.kms.outputs.instances[f.kms_key].key_id : null
      tags                   = try(f.tags, {})
    }
  }

  tags = include.root.locals.base_tags
}
