module "this" {
  source   = "../"
  for_each = var.instances

  name                   = each.key
  architecture           = each.value.architecture
  engine_version         = each.value.engine_version
  instance_class         = try(each.value.instance_class, null)
  storage_gb             = try(each.value.storage_gb, null)
  replication_factor     = try(each.value.replication_factor, null)
  readonly_replicas      = try(each.value.readonly_replicas, null)
  mongos                 = try(each.value.mongos, [])
  shards                 = try(each.value.shards, [])
  config_server          = try(each.value.config_server, null)
  storage_type           = try(each.value.storage_type, null)
  vpc_id                 = each.value.vpc_id
  vswitch_id             = each.value.vswitch_id
  zone_id                = each.value.zone_id
  secondary_zone_id      = try(each.value.secondary_zone_id, null)
  hidden_zone_id         = try(each.value.hidden_zone_id, null)
  security_ips           = each.value.security_ips
  deletion_protection    = try(each.value.deletion_protection, null)
  backup                 = try(each.value.backup, null)
  disk_encryption_key_id = try(each.value.disk_encryption_key_id, null)
  parameters             = try(each.value.parameters, {})
  password               = try(var.mongodb_passwords[each.key], null)
  password_length        = try(each.value.password_length, null)
  tags                   = merge(var.tags, try(each.value.tags, {}))
}
