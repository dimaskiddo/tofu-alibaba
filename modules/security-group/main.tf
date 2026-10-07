resource "alicloud_security_group" "this" {
  security_group_name = var.name
  vpc_id              = var.vpc_id
  description         = var.description
  inner_access_policy = var.inner_access_policy
  tags                = var.tags
}

resource "alicloud_security_group_rule" "this" {
  for_each = local.rules

  security_group_id        = alicloud_security_group.this.id
  type                     = each.value.type
  ip_protocol              = each.value.ip_protocol
  port_range               = each.value.port_range
  cidr_ip                  = each.value.cidr_ip
  source_security_group_id = each.value.source_security_group_id
  policy                   = each.value.policy
  priority                 = each.value.priority
  description              = each.value.description
  # VPC security groups only accept intranet rules.
  nic_type = "intranet"
}
