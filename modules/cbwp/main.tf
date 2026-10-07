# no per-EIP cap (bandwidth_package_bandwidth), ratio, security_protection_types or resource_group_id; add when a tenant needs a per-IP limit or PayBy95.
resource "alicloud_common_bandwidth_package" "this" {
  bandwidth_package_name = var.name
  bandwidth              = tostring(var.bandwidth)
  internet_charge_type   = var.internet_charge_type
  isp                    = var.isp
  description            = var.description
  deletion_protection    = var.deletion_protection
  tags                   = var.tags
}

resource "alicloud_common_bandwidth_package_attachment" "this" {
  for_each             = var.eip_ids
  bandwidth_package_id = alicloud_common_bandwidth_package.this.id
  instance_id          = each.value
}

resource "alicloud_alb_load_balancer_common_bandwidth_package_attachment" "this" {
  for_each             = var.alb_ids
  load_balancer_id     = each.value
  bandwidth_package_id = alicloud_common_bandwidth_package.this.id
}
