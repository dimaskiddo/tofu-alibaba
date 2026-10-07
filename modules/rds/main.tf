data "alicloud_account" "this" {}

resource "alicloud_db_instance" "this" {
  instance_name            = var.name
  engine                   = var.engine
  engine_version           = var.engine_version
  category                 = var.category
  instance_type            = var.instance_type
  instance_storage         = var.instance_storage
  db_instance_storage_type = var.db_instance_storage_type
  instance_charge_type     = "Postpaid"
  zone_id                  = var.placement[0].zone_id
  # A Basic instance has no standby zone; a single placement on HighAvailability leaves the standby to Alibaba Cloud.
  zone_id_slave_a     = length(var.placement) > 1 ? var.placement[1].zone_id : null
  vswitch_id          = join(",", var.placement[*].vswitch_id)
  security_ips        = var.security_ips
  deletion_protection = var.deletion_protection
  maintain_time       = var.maintain_time
  encryption_key      = var.encryption_key
  role_arn            = local.role_arn
  storage_auto_scale  = var.storage_auto_scale == null ? "Disable" : "Enable"
  storage_threshold   = var.storage_auto_scale == null ? null : var.storage_auto_scale.threshold
  storage_upper_bound = var.storage_auto_scale == null ? null : var.storage_auto_scale.upper_bound
  tags                = var.tags

  dynamic "parameters" {
    for_each = var.parameters
    content {
      name  = parameters.value.name
      value = parameters.value.value
    }
  }
}

resource "alicloud_db_backup_policy" "this" {
  instance_id             = alicloud_db_instance.this.id
  preferred_backup_period = var.backup.preferred_backup_period
  preferred_backup_time   = var.backup.preferred_backup_time
  backup_retention_period = var.backup.backup_retention_period
  # Log backup is not available on Basic.
  enable_backup_log           = var.category != "Basic"
  log_backup_retention_period = var.category == "Basic" ? null : var.backup.log_backup_retention_period
}

resource "alicloud_db_database" "this" {
  for_each = local.databases

  instance_id    = alicloud_db_instance.this.id
  data_base_name = each.key
  character_set  = each.value.character_set
  description    = each.value.description
}

# Accounts without an entry in account_passwords get a random password; the alphanumeric set satisfies the validation.
resource "random_password" "account" {
  for_each = { for k, a in local.accounts : k => a if !contains(nonsensitive(keys(var.account_passwords)), k) }

  length      = var.password_length
  special     = false
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
}

resource "alicloud_rds_account" "this" {
  for_each = local.accounts

  db_instance_id      = alicloud_db_instance.this.id
  account_name        = each.key
  account_type        = each.value.type
  account_description = each.value.description
  account_password    = try(var.account_passwords[each.key], random_password.account[each.key].result)
}

resource "alicloud_db_account_privilege" "this" {
  for_each = local.grants

  instance_id  = alicloud_db_instance.this.id
  account_name = alicloud_rds_account.this[each.key].account_name
  privilege    = each.value.privilege
  db_names     = [for d in each.value.databases : alicloud_db_database.this[d].data_base_name]
}
