terraform_version_constraint  = "~> 1.10.0"
terragrunt_version_constraint = "~> 0.93.0"

# Without this a local run lacking TG_TF_PATH would fall back to Terraform.
terraform_binary = "tofu"

locals {
  tenant_file  = find_in_parent_folders("tenant.hcl")
  tenant_dir   = dirname(local.tenant_file)
  tenant_cfg   = read_terragrunt_config(local.tenant_file).locals
  provider_cfg = read_terragrunt_config(find_in_parent_folders("provider.hcl")).locals
  state_tpl    = read_terragrunt_config("${get_parent_terragrunt_dir()}/_common/state.hcl").locals

  tenant      = local.tenant_cfg.tenant
  environment = local.tenant_cfg.environment
  modules_dir = "${get_parent_terragrunt_dir()}/../modules"

  # Every *_ok local fails through lookup(), which surfaces the message in its error, unlike a bare condition.
  tags_ok   = lookup({ ok = "ok" }, try(length(local.tenant_cfg.base_tags) >= 1, false) ? "ok" : "tenant.hcl must define base_tags (at least one tag)")
  base_tags = local.tags_ok == "ok" ? local.tenant_cfg.base_tags : {}

  # A copied tenant that kept the old tenant.hcl would share the source tenant's state keys and credentials; the
  # character sets keep env prefixes such as A_B_C_ from colliding between tenants.
  tenant_ok = lookup({ ok = "ok" }, !can(regex("^[a-z]([a-z0-9-]*[a-z0-9])?$", local.tenant)) ? "tenant.hcl: tenant must match ^[a-z]([a-z0-9-]*[a-z0-9])?$" : (
    !can(regex("^[a-z0-9]+$", local.environment)) ? "tenant.hcl: environment must match ^[a-z0-9]+$ (no '-')" : (
      basename(local.tenant_dir) == "${local.tenant}-${local.environment}" ? "ok" : "tenant.hcl: tenant-environment '${local.tenant}-${local.environment}' must equal the tenant directory name '${basename(local.tenant_dir)}'"
    )
  ))

  # Every user-editable value of a leaf lives in its instance files, keyed by their `name` value, never by the
  # file name: renaming a file must not change a for_each key and so must not touch state.
  # Files sit next to terragrunt.hcl, or one folder down in a group folder (subnet/<vpc-name>/); a folder that
  # holds its own terragrunt.hcl is another leaf, not a group. There is no aggregate file.
  leaf_dir  = get_terragrunt_dir()
  leaf_path = trimprefix(local.leaf_dir, "${local.tenant_dir}/")

  # trimprefix leaves the input unchanged when the leaf is not under the tenant dir, which would corrupt the state key.
  path_ok = lookup({ ok = "ok" }, local.leaf_path == local.leaf_dir ? "leaf ${local.leaf_dir} is not under the tenant directory ${local.tenant_dir}" : "ok")

  # Dotfiles such as .terraform.lock.hcl are tool output, not instance files.
  own_files = [for f in fileset(local.leaf_dir, "*.hcl") : f if f != "terragrunt.hcl" && substr(f, 0, 1) != "."]

  group_files = [
    for f in fileset(local.leaf_dir, "*/*.hcl") : f
    if substr(basename(f), 0, 1) != "." && !fileexists("${local.leaf_dir}/${dirname(f)}/terragrunt.hcl")
  ]

  raw = merge(
    { for f in local.own_files : f => read_terragrunt_config("${local.leaf_dir}/${f}").locals },
    { for f in local.group_files : f => merge(read_terragrunt_config("${local.leaf_dir}/${f}").locals, { group = dirname(f) }) },
  )

  unnamed = [for f, v in local.raw : f if !can(v.name)]

  # A duplicate name fails here as "Duplicate object key"; a missing name is reported by leaf_ok.
  instances = { for f, v in local.raw : try(v.name, f) => v }

  leaf_ok = lookup({ ok = "ok" }, length(local.raw) == 0 ? "leaf ${local.leaf_path}: no instance file (*.hcl) found" : (
    length(local.unnamed) > 0 ? "leaf ${local.leaf_path}: instance file without a name value: ${join(", ", local.unnamed)}" : "ok"
  ))

  # Dependency outputs substituted for validate/init only, never for plan. any_cidr contains every subnet
  # so validation does not depend on the tenant's real CIDRs; vpc_cidr is a documentation range.
  mock = {
    any_cidr = "0.0.0.0/0"
    vpc_cidr = "192.0.2.0/24"
  }

  # State identity: <tenant>/<env>/<leaf path under tenant dir>/<stack>.tfstate, stack = <leaf path with - >-<tenant>-<env>
  stack     = "${replace(local.leaf_path, "/", "-")}-${local.tenant}-${local.environment}"
  key       = "${local.tenant}/${local.environment}/${local.leaf_path}/${local.stack}.tfstate"
  http_name = replace(local.key, "/", "--")

  state      = local.tenant_cfg.state
  type_known = contains(keys(local.state_tpl.required), try(local.state.type, ""))
  type       = local.type_known ? local.state.type : ""

  # An empty or blank value would otherwise produce a backend with an empty bucket or URL.
  missing = [for k in lookup(local.state_tpl.required, local.type, []) : k if trimspace(try(tostring(local.state[k]), "")) == ""]

  # OSS rejects If-None-Match, which the s3 backend's lockfile needs, so s3 against OSS would run without a lock.
  s3_on_oss = local.type == "s3" && can(regex("(?i)aliyuncs\\.com", try(local.state.endpoint, "")))

  settings_ok = lookup({ ok = "ok" }, !local.type_known ? "tenant.hcl: state.type must be one of: ${join(", ", sort(keys(local.state_tpl.required)))}" : (
    length(local.missing) > 0 ? "state.${local.type} is missing settings: ${join(", ", local.missing)}" : (
      local.s3_on_oss ? "tenant.hcl: state.s3 cannot lock on Alibaba OSS (OSS rejects If-None-Match); use type = \"oss\" with tablestore_endpoint and tablestore_table" : "ok"
    )
  ))

  base_url = trimsuffix(try(local.state.base_url, ""), "/")
  http_address = local.type == "gitlab" ? "${local.base_url}/api/v4/projects/${try(local.state.project_id, "")}/terraform/state/${local.http_name}" : (
    local.type == "gitea" ? "${local.base_url}/api/packages/${try(local.state.owner, "")}/terraform/state/${local.http_name}" :
    "${local.base_url}/${local.http_name}"
  )

  s3_backend = replace(replace(replace(replace(local.state_tpl.s3_template,
    "__BUCKET__", try(local.state.bucket, "")),
    "__KEY__", local.key),
    "__REGION__", try(local.state.region, "")),
  "__ENDPOINT__", try(local.state.endpoint, ""))

  # prefix + key joins to the same object path as the s3 key: <tenant>/<env>/<leaf path>/<stack>.tfstate.
  oss_backend = replace(replace(replace(replace(replace(replace(replace(local.state_tpl.oss_template,
    "__BUCKET__", try(local.state.bucket, "")),
    "__PREFIX__", "${local.tenant}/${local.environment}/${local.leaf_path}"),
    "__NAME__", "${local.stack}.tfstate"),
    "__REGION__", try(local.state.region, "")),
    "__ENDPOINT__", try(local.state.endpoint, "")),
    "__TS_ENDPOINT__", try(local.state.tablestore_endpoint, "")),
  "__TS_TABLE__", try(local.state.tablestore_table, ""))

  http_backend = replace(replace(replace(local.state_tpl.http_template,
    "__ADDRESS__", local.http_address),
    "__LOCK_METHOD__", local.type == "http" ? "LOCK" : "POST"),
  "__UNLOCK_METHOD__", local.type == "http" ? "UNLOCK" : "DELETE")

  # Every env var is prefixed with the upper-case tenant and environment (EXAMPLE_STAGE_), mapped here to the name the provider/backend/module reads, so one
  # Atlantis server can hold several tenants. Values reach only the tofu process environment, never a file.
  env_prefix = upper(replace("${local.tenant}_${local.environment}_", "-", "_"))
  env_required = merge(
    { ALIBABA_CLOUD_ACCESS_KEY_ID = "ALIBABA_CLOUD_ACCESS_KEY_ID", ALIBABA_CLOUD_ACCESS_KEY_SECRET = "ALIBABA_CLOUD_ACCESS_KEY_SECRET" },
    local.type == "s3" ?
    { AWS_ACCESS_KEY_ID = "STATE_ACCESS_KEY_ID", AWS_SECRET_ACCESS_KEY = "STATE_SECRET_ACCESS_KEY" } : (
      # The oss backend reads ALICLOUD_ACCESS_KEY_ID/_SECRET; the provider reads neither, so state credentials never reach it.
      local.type == "oss" ?
      { ALICLOUD_ACCESS_KEY_ID = "STATE_ACCESS_KEY_ID", ALICLOUD_ACCESS_KEY_SECRET = "STATE_SECRET_ACCESS_KEY" } :
      { TF_HTTP_USERNAME = "STATE_USERNAME", TF_HTTP_PASSWORD = "STATE_PASSWORD" }
    ),
  )

  # Unset means the module generates a random password.
  env_optional = {
    TF_VAR_password                = "ECS_PASSWORD"
    TF_VAR_account_passwords       = "RDS_ACCOUNT_PASSWORDS"
    TF_VAR_redis_passwords         = "REDIS_PASSWORDS"
    TF_VAR_kafka_sasl_passwords    = "KAFKA_SASL_PASSWORDS"
    TF_VAR_elasticsearch_passwords = "ELASTICSEARCH_PASSWORDS"
  }
  env_vars = { for k, v in merge(local.env_required, local.env_optional) : k => get_env("${local.env_prefix}${v}", "") if get_env("${local.env_prefix}${v}", "") != "" }

  # Read by leaf terragrunt.hcl as include.root.locals.tenant_env, so instance files never call get_env.
  tenant_env = {
    ecs_image_id    = get_env("${local.env_prefix}ECS_IMAGE_ID", "")
    kms_instance_id = get_env("${local.env_prefix}KMS_INSTANCE_ID", "")
  }

  # Offline commands (validate, render, hcl fmt) need no credentials.
  env_commands = ["init", "plan", "apply", "destroy", "output", "import", "refresh", "show", "state", "force-unlock", "taint", "untaint", "console", "workspace"]
  env_missing  = [for k, v in local.env_required : "${local.env_prefix}${v}" if get_env("${local.env_prefix}${v}", "") == ""]

  # A global TF_VAR_* would be overridden by env_vars or silently feed another tenant's value; a global credential,
  # token, profile or role would let the process authenticate as another tenant or account. All are refused.
  env_global = [
    "TF_VAR_password", "TF_VAR_account_passwords",
    "TF_VAR_region", "TF_VAR_zones", "TF_VAR_tags", "TF_VAR_instances", "TF_VAR_groups", "TF_VAR_eips", "TF_VAR_private_key_dir",
    "TF_VAR_redis_passwords", "TF_VAR_kafka_sasl_passwords", "TF_VAR_elasticsearch_passwords",
    "ALICLOUD_ACCESS_KEY", "ALICLOUD_SECRET_KEY", "ALICLOUD_SECURITY_TOKEN", "ALIBABA_CLOUD_SECURITY_TOKEN",
    "ALIBABA_CLOUD_PROFILE", "ALICLOUD_PROFILE", "ALIBABA_CLOUD_ROLE_ARN", "ALICLOUD_ASSUME_ROLE_ARN",
    "AWS_SESSION_TOKEN", "AWS_PROFILE",
  ]
  env_legacy = [for k in local.env_global : k if get_env(k, "") != ""]
  env_check  = contains(local.env_commands, get_terraform_command())

  env_ok = lookup({ ok = "ok" }, !local.env_check ? "ok" : (
    length(local.env_missing) > 0 ? "missing environment variables: ${join(", ", local.env_missing)}" : (
      length(local.env_legacy) > 0 ? "${join("; ", [for k in local.env_legacy : "global ${k} is set"])}; unset it and use the ${local.env_prefix}-prefixed variables (e.g. ${local.env_prefix}ECS_PASSWORD / ${local.env_prefix}REDIS_PASSWORDS)" : "ok"
    )
  ))

  region_ok = lookup({ ok = "ok" }, can(regex("^[a-z]{2}-[a-z0-9-]+$", try(local.provider_cfg.region, ""))) ? "ok" : "provider.hcl: region must be an Alibaba Cloud region ID, e.g. ap-southeast-5")

  backend_hcl = alltrue([for c in [local.tenant_ok, local.path_ok, local.settings_ok, local.leaf_ok, local.env_ok, local.region_ok] : c == "ok"]) ? (local.type == "s3" ? local.s3_backend : (local.type == "oss" ? local.oss_backend : local.http_backend)) : ""
}

terraform {
  extra_arguments "tenant_env" {
    commands = local.env_commands
    env_vars = local.env_vars
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOT
    variable "region" {
      type        = string
      description = "Alibaba Cloud region, supplied by the implementor (provider.hcl)."

      validation {
        condition     = can(regex("^[a-z]{2}-[a-z0-9-]+$", var.region))
        error_message = "region must be set to a valid Alibaba Cloud region ID, e.g. ap-southeast-5."
      }
    }

    # Credentials are injected by Terragrunt (root.hcl) from the tenant's environment variables.
    provider "alicloud" {
      region = var.region
    }
  EOT
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = local.backend_hcl
}

inputs = {
  region = local.provider_cfg.region
  zones  = local.provider_cfg.zones
  tags   = local.base_tags
}
