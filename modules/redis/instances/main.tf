module "this" {
  source   = "../"
  for_each = var.instances

  name                      = each.key
  instance_type             = each.value.instance_type
  engine_version            = each.value.engine_version
  instance_class            = each.value.instance_class
  vpc_id                    = try(each.value.vpc_id, null)
  vswitch_id                = each.value.vswitch_id
  zone_id                   = each.value.zone_id
  secondary_zone_id         = try(each.value.secondary_zone_id, null)
  shard_count               = try(each.value.shard_count, null)
  storage_size_gb           = try(each.value.storage_size_gb, null)
  storage_performance_level = try(each.value.storage_performance_level, null)
  security_ips              = each.value.security_ips
  deletion_protection       = try(each.value.deletion_protection, null)
  password                  = try(var.redis_passwords[each.key], null)
  password_length           = try(each.value.password_length, null)
  tags                      = merge(var.tags, try(each.value.tags, {}))
}
