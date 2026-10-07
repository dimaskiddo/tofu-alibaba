locals {
  is_rs    = var.architecture == "replica_set"
  generate = nonsensitive(var.password == null)
  password = local.generate ? random_password.this[0].result : var.password
}

# Letters and digits satisfy the 3-of-4 class rule and need no escaping in connection strings.
resource "random_password" "this" {
  count = local.generate ? 1 : 0

  length      = var.password_length
  special     = false
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
}

# pay-as-you-go only; destroying a PrePaid instance merely drops it from state. Add billing inputs when a subscription is needed.
resource "alicloud_mongodb_instance" "this" {
  count = local.is_rs ? 1 : 0

  name                           = var.name
  engine_version                 = var.engine_version
  db_instance_class              = var.instance_class
  db_instance_storage            = var.storage_gb
  replication_factor             = var.replication_factor
  readonly_replicas              = var.readonly_replicas
  storage_type                   = var.storage_type
  instance_charge_type           = "PostPaid"
  vpc_id                         = var.vpc_id
  vswitch_id                     = var.vswitch_id
  zone_id                        = var.zone_id
  secondary_zone_id              = var.secondary_zone_id
  hidden_zone_id                 = var.hidden_zone_id
  security_ip_list               = var.security_ips
  account_password               = local.password
  db_instance_release_protection = var.deletion_protection
  encrypted                      = var.disk_encryption_key_id == null ? null : true
  cloud_disk_encryption_key      = var.disk_encryption_key_id
  backup_period                  = var.backup == null ? null : var.backup.period
  backup_time                    = var.backup == null ? null : var.backup.time
  backup_retention_period        = var.backup == null ? null : var.backup.retention_days
  tags                           = var.tags

  dynamic "parameters" {
    for_each = var.parameters

    content {
      name  = parameters.key
      value = parameters.value
    }
  }
}

resource "alicloud_mongodb_sharding_instance" "this" {
  count = local.is_rs ? 0 : 1

  name                           = var.name
  engine_version                 = var.engine_version
  storage_type                   = var.storage_type
  instance_charge_type           = "PostPaid"
  vpc_id                         = var.vpc_id
  vswitch_id                     = var.vswitch_id
  zone_id                        = var.zone_id
  secondary_zone_id              = var.secondary_zone_id
  hidden_zone_id                 = var.hidden_zone_id
  security_ip_list               = var.security_ips
  account_password               = local.password
  db_instance_release_protection = var.deletion_protection
  encrypted                      = var.disk_encryption_key_id == null ? null : true
  cloud_disk_encryption_key      = var.disk_encryption_key_id
  backup_period                  = var.backup == null ? null : var.backup.period
  backup_time                    = var.backup == null ? null : var.backup.time
  backup_retention_period        = var.backup == null ? null : var.backup.retention_days
  tags                           = var.tags

  dynamic "mongo_list" {
    for_each = var.mongos

    content {
      node_class = mongo_list.value.node_class
    }
  }

  dynamic "shard_list" {
    for_each = var.shards

    content {
      node_class        = shard_list.value.node_class
      node_storage      = shard_list.value.node_storage
      readonly_replicas = shard_list.value.readonly_replicas
    }
  }

  dynamic "config_server_list" {
    for_each = var.config_server == null ? [] : [var.config_server]

    content {
      node_class   = config_server_list.value.node_class
      node_storage = config_server_list.value.node_storage
    }
  }

  dynamic "parameters" {
    for_each = var.parameters

    content {
      name  = parameters.key
      value = parameters.value
    }
  }
}
