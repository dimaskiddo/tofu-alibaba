locals {
  is_oss   = var.instance_type == "Redis"
  generate = nonsensitive(var.password == null)
  password = local.generate ? random_password.this[0].result : var.password
}

# Letters and digits satisfy the 3-of-4 class rule and need no escaping in client URLs.
resource "random_password" "this" {
  count = local.generate ? 1 : 0

  length      = var.password_length
  special     = false
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
}

# pay-as-you-go only; destroying a PrePaid/Subscription instance merely drops it from state. Add billing inputs when a subscription is needed.
resource "alicloud_kvstore_instance" "this" {
  count = local.is_oss ? 1 : 0

  db_instance_name            = var.name
  instance_class              = var.instance_class
  instance_type               = "Redis"
  engine_version              = var.engine_version
  payment_type                = "PostPaid"
  zone_id                     = var.zone_id
  secondary_zone_id           = var.secondary_zone_id
  vswitch_id                  = var.vswitch_id
  security_ips                = var.security_ips
  shard_count                 = var.shard_count
  password                    = local.password
  instance_release_protection = coalesce(var.deletion_protection, false)
  tags                        = var.tags
}

resource "alicloud_redis_tair_instance" "this" {
  count = local.is_oss ? 0 : 1

  tair_instance_name = var.name
  instance_class     = var.instance_class
  instance_type      = var.instance_type
  engine_version     = var.engine_version
  payment_type       = "PayAsYouGo"
  vpc_id             = var.vpc_id
  zone_id            = var.zone_id
  secondary_zone_id  = var.secondary_zone_id
  vswitch_id         = var.vswitch_id
  security_ips       = join(",", var.security_ips)
  shard_count        = var.shard_count
  password           = local.password
  tags               = var.tags

  storage_size_gb           = var.storage_size_gb
  storage_performance_level = var.storage_performance_level
}
