resource "alicloud_eip_address" "this" {
  for_each = local.eips

  address_name         = each.value.name
  description          = each.value.description
  bandwidth            = tostring(each.value.bandwidth)
  internet_charge_type = each.value.internet_charge_type
  isp                  = each.value.isp
  # Subscription needs period/pricing_cycle/auto_pay; only pay-as-you-go is supported.
  payment_type = "PayAsYouGo"
  tags         = merge(var.tags, each.value.tags)
}

resource "alicloud_eip_association" "this" {
  for_each = local.associations

  allocation_id = alicloud_eip_address.this[each.key].id
  instance_id   = each.value
  # The provider defaults to EcsInstance, which the API rejects for ENI and HAVIP IDs.
  instance_type = startswith(each.value, "eni-") ? "NetworkInterface" : startswith(each.value, "havip-") ? "HaVip" : null
}
