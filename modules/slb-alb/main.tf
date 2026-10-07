resource "alicloud_alb_load_balancer" "this" {
  load_balancer_name    = var.name
  vpc_id                = var.vpc_id
  address_type          = var.address_type
  load_balancer_edition = var.load_balancer_edition
  tags                  = var.tags

  load_balancer_billing_config {
    pay_type = "PayAsYouGo"
  }

  dynamic "zone_mappings" {
    for_each = var.zone_mappings

    content {
      zone_id    = zone_mappings.value.zone_id
      vswitch_id = zone_mappings.value.vswitch_id
    }
  }

  lifecycle {
    # The cbwp attachment sets bandwidth_package_id; inline it is ForceNew and would replace the ALB.
    ignore_changes = [bandwidth_package_id]

    precondition {
      condition     = alltrue([for z in var.zone_mappings : contains(var.zones, z.zone_id)])
      error_message = "Every zone_mappings zone_id must be one of the registered zones."
    }
  }
}

resource "alicloud_alb_server_group" "this" {
  for_each = var.server_groups

  server_group_name = each.key
  vpc_id            = var.vpc_id
  protocol          = each.value.protocol
  scheduler         = each.value.scheduler
  server_group_type = "Instance"
  tags              = var.tags

  health_check_config {
    health_check_enabled      = each.value.health_check.enabled
    health_check_protocol     = each.value.health_check.protocol
    health_check_path         = contains(["HTTP", "HTTPS"], each.value.health_check.protocol) ? each.value.health_check.path : null
    health_check_codes        = contains(["HTTP", "HTTPS"], each.value.health_check.protocol) ? each.value.health_check.codes : null
    health_check_connect_port = each.value.health_check.port
  }

  # Always sent: dropping the block never sends StickySessionEnabled=false, so turning sticky off would not stick.
  sticky_session_config {
    sticky_session_enabled = each.value.sticky
    sticky_session_type    = each.value.sticky ? "Insert" : null
  }

  dynamic "servers" {
    for_each = each.value.servers

    content {
      server_id   = servers.value.server_id
      server_type = servers.value.server_type
      port        = servers.value.port
      weight      = servers.value.weight
    }
  }
}

resource "alicloud_alb_listener" "this" {
  for_each = var.listeners

  load_balancer_id     = alicloud_alb_load_balancer.this.id
  listener_protocol    = each.value.protocol
  listener_port        = each.value.port
  listener_description = each.value.description
  tags                 = var.tags

  default_actions {
    type = "ForwardGroup"

    forward_group_config {
      server_group_tuples {
        server_group_id = alicloud_alb_server_group.this[each.value.default_server_group].id
      }
    }
  }

  dynamic "certificates" {
    for_each = each.value.certificate_id == null ? [] : [each.value.certificate_id]

    content {
      certificate_id = certificates.value
    }
  }

  lifecycle {
    precondition {
      condition     = contains(keys(var.server_groups), each.value.default_server_group)
      error_message = "Listener ${each.key}: default_server_group ${each.value.default_server_group} is not a key of server_groups."
    }
  }
}

resource "alicloud_alb_rule" "this" {
  for_each = var.rules

  listener_id = alicloud_alb_listener.this[each.value.listener].id
  rule_name   = each.key
  priority    = each.value.priority
  direction   = "Request"

  dynamic "rule_conditions" {
    for_each = length(each.value.hosts) > 0 ? [each.value.hosts] : []

    content {
      type = "Host"

      host_config {
        values = rule_conditions.value
      }
    }
  }

  dynamic "rule_conditions" {
    for_each = length(each.value.paths) > 0 ? [each.value.paths] : []

    content {
      type = "Path"

      path_config {
        values = rule_conditions.value
      }
    }
  }

  dynamic "rule_actions" {
    for_each = each.value.server_group == null ? [] : [each.value.server_group]

    content {
      type  = "ForwardGroup"
      order = 1

      forward_group_config {
        server_group_tuples {
          server_group_id = alicloud_alb_server_group.this[rule_actions.value].id
        }
      }
    }
  }

  dynamic "rule_actions" {
    for_each = each.value.fixed_response == null ? [] : [each.value.fixed_response]

    content {
      type  = "FixedResponse"
      order = 1

      fixed_response_config {
        content      = rule_actions.value.content
        content_type = rule_actions.value.content_type
        http_code    = rule_actions.value.http_code
      }
    }
  }

  lifecycle {
    precondition {
      condition     = contains(keys(var.listeners), each.value.listener)
      error_message = "Rule ${each.key}: listener ${each.value.listener} is not a key of listeners."
    }

    precondition {
      condition     = each.value.server_group == null || contains(keys(var.server_groups), each.value.server_group)
      error_message = "Rule ${each.key}: server_group ${each.value.server_group != null ? each.value.server_group : "(none)"} is not a key of server_groups."
    }
  }
}
