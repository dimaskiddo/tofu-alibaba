include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "instance_type", "image_id", "zone_id", "subnet",
    "security_groups", "private_ip", "key_name", "public_key", "generate_key_pair", "password_length",
    "description", "user_data", "user_data_file", "internet_max_bw_out", "deletion_protection", "system_disk_category", "system_disk_size",
    "system_disk_performance_level", "system_disk_encrypted", "system_disk_kms_key", "data_disks",
  ]
  unknown = [
    for n, f in include.root.locals.instances : "instance ${n}: unknown key(s) ${join(", ", sort(setsubtract(keys(f), local.known)))}"
    if length(setsubtract(keys(f), local.known)) > 0
  ]
  bad_user_data = concat(
    [for n, f in include.root.locals.instances : "instance ${n}: set user_data or user_data_file, not both" if can(f.user_data) && can(f.user_data_file)],
    [for n, f in include.root.locals.instances : "instance ${n}: user_data_file must be a relative path inside the leaf (no leading / and no ..)" if can(f.user_data_file) && (startswith(f.user_data_file, "/") || strcontains(f.user_data_file, ".."))],
  )
  problems = concat(local.unknown, local.bad_user_data)
  keys_ok  = lookup({ ok = "ok" }, length(local.problems) == 0 ? "ok" : join("; ", local.problems))
  members  = { for n, f in include.root.locals.instances : n => f if local.keys_ok == "ok" }
  kms_keys = distinct(flatten([
    for f in values(local.members) : concat(
      can(f.system_disk_kms_key) ? [f.system_disk_kms_key] : [],
      [for d in try(f.data_disks, []) : d.kms_key if can(d.kms_key)]
    )
  ]))
}

dependency "subnet" {
  config_path = "../subnet"

  mock_outputs = {
    subnet_ids   = { for s in distinct([for m in values(local.members) : m.subnet]) : s => "vsw-mock" }
    subnet_zones = merge([for m in values(local.members) : { (m.subnet) = m.zone_id }]...)
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "security_group" {
  config_path = "../security-group"

  mock_outputs = {
    instances = { for s in distinct(flatten([for m in values(local.members) : m.security_groups])) : s => { security_group_id = "sg-mock" } }
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
  source = "${include.root.locals.modules_dir}/ecs"
}

# Login per instance file: key_name, public_key or generate_key_pair; otherwise <TENANT>_<ENV>_ECS_PASSWORD, otherwise a
# random password (output generated_passwords). A generated private key is written once to private_key_dir.
inputs = {
  private_key_dir = get_terragrunt_dir()

  instances = {
    for n, f in local.members : n => {
      instance_type      = f.instance_type
      image_id           = try(f.image_id, include.root.locals.tenant_env.ecs_image_id)
      zone_id            = lookup({ ok = f.zone_id }, dependency.subnet.outputs.subnet_zones[f.subnet] == f.zone_id ? "ok" : "instance ${n}: zone_id ${f.zone_id} is not the zone of subnet ${f.subnet} (${dependency.subnet.outputs.subnet_zones[f.subnet]})")
      vswitch_id         = dependency.subnet.outputs.subnet_ids[f.subnet]
      security_group_ids = [for s in f.security_groups : dependency.security_group.outputs.instances[s].security_group_id]
      private_ip         = try(f.private_ip, null)
      key_name           = try(f.key_name, null)
      public_key         = try(f.public_key, null)
      generate_key_pair  = try(f.generate_key_pair, null)
      password_length    = try(f.password_length, null)
      host_name          = n
      description        = try(f.description, null)
      user_data          = can(f.user_data_file) ? file("${get_terragrunt_dir()}/${f.user_data_file}") : try(f.user_data, null)

      internet_max_bw_out = try(f.internet_max_bw_out, null)
      deletion_protection = try(f.deletion_protection, null)

      system_disk_category          = try(f.system_disk_category, null)
      system_disk_size              = try(f.system_disk_size, null)
      system_disk_performance_level = try(f.system_disk_performance_level, null)
      system_disk_encrypted         = try(f.system_disk_encrypted, null)
      system_disk_kms_key_id        = can(f.system_disk_kms_key) ? dependency.kms.outputs.instances[f.system_disk_kms_key].key_id : null
      data_disks = [
        for d in try(f.data_disks, []) : merge(
          { for k, v in d : k => v if k != "kms_key" },
          can(d.kms_key) ? { kms_key_id = dependency.kms.outputs.instances[d.kms_key].key_id } : {}
        )
      ]

      tags = try(f.tags, {})
    }
  }

  tags = include.root.locals.base_tags
}
