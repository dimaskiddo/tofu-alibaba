# Static backend templates. Leaf-dependent values (key, name) are substituted by root.hcl,
# because get_terragrunt_dir() inside a read_terragrunt_config target is this file's dir.
locals {
  required = {
    s3     = ["bucket", "region", "endpoint"]
    oss    = ["bucket", "region", "endpoint", "tablestore_endpoint", "tablestore_table"]
    gitlab = ["base_url", "project_id"]
    gitea  = ["base_url", "owner"]
    http   = ["base_url"]
  }

  s3_template = <<-EOT
    terraform {
      backend "s3" {
        bucket                      = "__BUCKET__"
        key                         = "__KEY__"
        region                      = "__REGION__"
        endpoints                   = { s3 = "__ENDPOINT__" }
        use_lockfile                = true
        skip_credentials_validation = true
        skip_requesting_account_id  = true
        skip_metadata_api_check     = true
        skip_region_validation      = true
        skip_s3_checksum            = true
      }
    }
  EOT

  # Both tablestore settings are required: the oss backend silently skips locking when tablestore_table is empty.
  oss_template = <<-EOT
    terraform {
      backend "oss" {
        bucket              = "__BUCKET__"
        prefix              = "__PREFIX__"
        key                 = "__NAME__"
        region              = "__REGION__"
        endpoint            = "__ENDPOINT__"
        tablestore_endpoint = "__TS_ENDPOINT__"
        tablestore_table    = "__TS_TABLE__"
        encrypt             = true
      }
    }
  EOT

  http_template = <<-EOT
    terraform {
      backend "http" {
        address        = "__ADDRESS__"
        lock_address   = "__ADDRESS__/lock"
        unlock_address = "__ADDRESS__/lock"
        lock_method    = "__LOCK_METHOD__"
        unlock_method  = "__UNLOCK_METHOD__"
      }
    }
  EOT
}
