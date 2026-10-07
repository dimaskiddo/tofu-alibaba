# pay-as-you-go and VPC-only (deploy_type 5, no eip_max); PrePaid destroy only drops the instance from state, and Internet access needs a reviewed exception.
resource "alicloud_alikafka_instance" "this" {
  name            = var.name
  deploy_type     = 5
  paid_type       = "PostPaid"
  partition_num   = var.partition_num
  disk_type       = var.disk_type == "ssd" ? 1 : 0
  disk_size       = var.disk_size
  io_max_spec     = var.io_max_spec
  spec_type       = var.spec_type
  service_version = var.service_version
  vswitch_ids     = var.placement[*].vswitch_id
  zone_id         = var.placement[0].zone_id
  selected_zones  = length(var.placement) > 1 ? var.placement[*].zone_id : null
  security_group  = var.security_group_id
  config          = length(var.sasl_users) > 0 ? jsonencode({ "enable.acl" = "true" }) : null
  tags            = var.tags
}

resource "alicloud_alikafka_instance_allowed_ip_attachment" "this" {
  for_each = local.allowed

  instance_id  = alicloud_alikafka_instance.this.id
  allowed_type = "vpc"
  port_range   = each.value.port_range
  allowed_ip   = each.value.ip
}

resource "alicloud_alikafka_topic" "this" {
  for_each = local.topics

  instance_id   = alicloud_alikafka_instance.this.id
  topic         = each.key
  remark        = coalesce(each.value.remark, replace(each.key, ".", "-"))
  partition_num = each.value.partition_num
  compact_topic = each.value.compact_topic
  local_topic   = each.value.local_topic
  tags          = var.tags
}

resource "alicloud_alikafka_consumer_group" "this" {
  for_each = local.groups

  instance_id = alicloud_alikafka_instance.this.id
  consumer_id = each.key
  remark      = coalesce(each.value.remark, replace(each.key, ".", "-"))
  tags        = var.tags
}

# Users without an entry in sasl_passwords get a random password; letters and digits satisfy the SASL character rule.
resource "random_password" "sasl" {
  for_each = { for k, u in local.users : k => u if !contains(nonsensitive(keys(var.sasl_passwords)), k) }

  length      = var.password_length
  special     = false
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
}

resource "alicloud_alikafka_sasl_user" "this" {
  for_each = local.users

  instance_id = alicloud_alikafka_instance.this.id
  username    = each.key
  type        = each.value.type
  password    = try(var.sasl_passwords[each.key], random_password.sasl[each.key].result)
}

resource "alicloud_alikafka_sasl_acl" "this" {
  for_each = local.acls

  instance_id               = alicloud_alikafka_instance.this.id
  username                  = alicloud_alikafka_sasl_user.this[each.value.user].username
  acl_resource_type         = each.value.resource_type
  acl_resource_name         = each.value.resource_name
  acl_resource_pattern_type = each.value.pattern
  acl_operation_type        = each.value.operation
}
