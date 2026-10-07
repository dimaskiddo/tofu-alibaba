include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  known = [
    "name", "tags", "vpc", "subnet", "es_version", "zone_count", "data_node", "master_node_spec",
    "kibana_node_spec", "protocol", "private_whitelist", "password_length",
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
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "subnet" {
  config_path = "../subnet"

  mock_outputs = {
    subnet_ids = { for s in distinct([for f in values(local.members) : f.subnet]) : s => "vsw-mock" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

terraform {
  source = "${include.root.locals.modules_dir}//elasticsearch/instances"
}

# The elastic password may come from <TENANT>_<ENV>_ELASTICSEARCH_PASSWORDS, shaped { "<instance>" = "<password>" };
# an instance without an entry gets a random password (output generated_passwords).
inputs = {
  instances = {
    for n, f in local.members : n => {
      es_version        = f.es_version
      vswitch_id        = dependency.subnet.outputs.subnet_ids[f.subnet]
      zone_count        = try(f.zone_count, null)
      data_node         = f.data_node
      master_node_spec  = try(f.master_node_spec, null)
      kibana_node_spec  = try(f.kibana_node_spec, null)
      protocol          = try(f.protocol, null)
      private_whitelist = try(f.private_whitelist, [dependency.vpc.outputs.instances[f.vpc].cidr_block])
      password_length   = try(f.password_length, null)
      tags              = try(f.tags, {})
    }
  }

  tags = include.root.locals.base_tags
}
