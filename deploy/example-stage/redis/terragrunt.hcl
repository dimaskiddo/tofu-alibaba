include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "vpc", "subnet", "instance_type", "engine_version", "instance_class",
    "zone_id", "secondary_zone_id", "shard_count", "storage_size_gb", "storage_performance_level", "security_ips", "deletion_protection", "password_length",
  ]
  unknown = [
    for n, f in include.root.locals.instances : "instance ${n}: unknown key(s) ${join(", ", sort(setsubtract(keys(f), local.known)))}"
    if length(setsubtract(keys(f), local.known)) > 0
  ]
  keys_ok = lookup({ ok = "ok" }, length(local.unknown) == 0 ? "ok" : join("; ", local.unknown))
  members = { for n, f in include.root.locals.instances : n => f if local.keys_ok == "ok" }
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

terraform {
  source = "${include.root.locals.modules_dir}//redis/instances"
}

# The default-account password may come from <TENANT>_<ENV>_REDIS_PASSWORDS, shaped { "<instance>" = "<password>" };
# an instance without an entry gets a random password (output generated_passwords).
inputs = {
  instances = {
    for n, f in local.members : n => {
      instance_type             = f.instance_type
      engine_version            = f.engine_version
      instance_class            = f.instance_class
      vpc_id                    = dependency.vpc.outputs.instances[f.vpc].vpc_id
      vswitch_id                = dependency.subnet.outputs.subnet_ids[f.subnet]
      zone_id                   = lookup({ ok = f.zone_id }, dependency.subnet.outputs.subnet_zones[f.subnet] == f.zone_id ? "ok" : "instance ${n}: zone_id ${f.zone_id} is not the zone of subnet ${f.subnet} (${dependency.subnet.outputs.subnet_zones[f.subnet]})")
      secondary_zone_id         = try(f.secondary_zone_id, null)
      shard_count               = try(f.shard_count, null)
      storage_size_gb           = try(f.storage_size_gb, null)
      storage_performance_level = try(f.storage_performance_level, null)
      security_ips              = try(f.security_ips, [dependency.vpc.outputs.instances[f.vpc].cidr_block])
      deletion_protection       = try(f.deletion_protection, null)
      password_length           = try(f.password_length, null)
      tags                      = try(f.tags, {})
    }
  }

  tags = include.root.locals.base_tags
}
