module "this" {
  source   = "../"
  for_each = var.instances

  name              = each.key
  partition_num     = each.value.partition_num
  disk_type         = each.value.disk_type
  disk_size         = each.value.disk_size
  io_max_spec       = each.value.io_max_spec
  spec_type         = try(each.value.spec_type, null)
  service_version   = try(each.value.service_version, null)
  placement         = each.value.placement
  security_group_id = try(each.value.security_group_id, null)
  allowed_ips       = each.value.allowed_ips
  topics            = try(each.value.topics, null)
  consumer_groups   = try(each.value.consumer_groups, null)
  sasl_users        = try(each.value.sasl_users, null)
  sasl_passwords    = try(var.kafka_sasl_passwords[each.key], {})
  password_length   = try(each.value.password_length, null)
  tags              = merge(var.tags, try(each.value.tags, {}))
}
