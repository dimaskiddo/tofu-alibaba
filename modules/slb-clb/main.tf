resource "alicloud_slb_load_balancer" "this" {
  load_balancer_name   = var.name
  address_type         = var.address_type
  vswitch_id           = var.address_type == "intranet" ? var.vswitch_id : null
  master_zone_id       = var.master_zone_id
  slave_zone_id        = var.slave_zone_id
  load_balancer_spec   = var.load_balancer_spec
  internet_charge_type = var.internet_charge_type
  payment_type         = "PayAsYouGo"
  tags                 = var.tags

  lifecycle {
    precondition {
      condition     = var.master_zone_id == null || contains(var.zones, var.master_zone_id)
      error_message = "master_zone_id must be one of the registered zones."
    }

    precondition {
      condition     = var.slave_zone_id == null || contains(var.zones, var.slave_zone_id)
      error_message = "slave_zone_id must be one of the registered zones."
    }

    precondition {
      condition     = var.slave_zone_id == null || var.slave_zone_id != var.master_zone_id
      error_message = "slave_zone_id must differ from master_zone_id."
    }
  }
}

resource "alicloud_slb_server_group" "this" {
  for_each = local.server_groups

  load_balancer_id = alicloud_slb_load_balancer.this.id
  name             = each.value
  tags             = var.tags
}

resource "alicloud_slb_server_group_server_attachment" "this" {
  for_each = var.backend_servers

  server_group_id = alicloud_slb_server_group.this["this"].id
  server_id       = each.value.server_id
  port            = each.value.port
  weight          = each.value.weight
  type            = each.value.type
}

resource "alicloud_slb_listener" "this" {
  for_each = var.listeners

  load_balancer_id      = alicloud_slb_load_balancer.this.id
  protocol              = each.value.protocol
  frontend_port         = each.value.frontend_port
  backend_port          = length(var.backend_servers) > 0 ? null : each.value.backend_port
  server_group_id       = length(var.backend_servers) > 0 ? alicloud_slb_server_group.this["this"].id : null
  scheduler             = each.value.scheduler
  bandwidth             = each.value.bandwidth
  server_certificate_id = each.value.server_certificate_id

  depends_on = [alicloud_slb_server_group_server_attachment.this]

  lifecycle {
    precondition {
      condition     = length(var.backend_servers) > 0 || each.value.backend_port != null
      error_message = "Listener ${each.key}: set backend_port or provide backend_servers."
    }
  }
}
