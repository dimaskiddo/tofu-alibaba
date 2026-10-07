mock_provider "alicloud" {}

variables {
  name                  = "main-1-c1-example-stage"
  load_balancer_edition = "Basic"
  vpc_id                = "vpc-abc"
  zones                 = ["ap-southeast-5a", "ap-southeast-5b"]
  tags                  = { env = "stage" }
  zone_mappings = [
    { zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" },
    { zone_id = "ap-southeast-5b", vswitch_id = "vsw-b" },
  ]
  server_groups = {
    web = { servers = [{ server_id = "i-a", port = 8080 }] }
  }
  listeners = {
    http = { protocol = "HTTP", port = 80, default_server_group = "web" }
  }
}

run "valid_multi_zone" {
  command = plan

  assert {
    condition     = length(alicloud_alb_server_group.this) == 1 && length(alicloud_alb_listener.this) == 1 && length(alicloud_alb_rule.this) == 0
    error_message = "LB, server group and listener must be planned"
  }

  assert {
    condition     = alicloud_alb_load_balancer.this.tags["env"] == "stage" && length(alicloud_alb_load_balancer.this.zone_mappings) == 2
    error_message = "tags and both zones must propagate"
  }
}

run "valid_with_rules_and_https" {
  command = plan
  variables {
    listeners = {
      https = { protocol = "HTTPS", port = 443, default_server_group = "web", certificate_id = "cert-1" }
    }
    rules = {
      api = { listener = "https", priority = 10, paths = ["/api"], server_group = "web" }
      off = { listener = "https", priority = 20, hosts = ["maint.example.com"], fixed_response = { content = "down" } }
    }
  }

  assert {
    condition     = length(alicloud_alb_rule.this) == 2
    error_message = "both rules must be planned"
  }
}

run "single_zone_rejected" {
  command = plan
  variables {
    zone_mappings = [{ zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" }]
  }
  expect_failures = [var.zone_mappings]
}

run "duplicate_zone_rejected" {
  command = plan
  variables {
    zone_mappings = [
      { zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" },
      { zone_id = "ap-southeast-5a", vswitch_id = "vsw-b" },
    ]
  }
  expect_failures = [var.zone_mappings]
}

run "unregistered_zone_rejected" {
  command = plan
  variables {
    zones = ["ap-southeast-5a"]
  }
  expect_failures = [alicloud_alb_load_balancer.this]
}

run "empty_zones_rejected" {
  command = plan
  variables { zones = [] }
  expect_failures = [var.zones]
}

run "empty_tags_rejected" {
  command = plan
  variables { tags = {} }
  expect_failures = [var.tags]
}

run "listener_port_zero_rejected" {
  command = plan
  variables { listeners = { http = { protocol = "HTTP", port = 0, default_server_group = "web" } } }
  expect_failures = [var.listeners]
}

run "listener_port_65536_rejected" {
  command = plan
  variables { listeners = { http = { protocol = "HTTP", port = 65536, default_server_group = "web" } } }
  expect_failures = [var.listeners]
}

run "https_without_certificate_rejected" {
  command = plan
  variables { listeners = { https = { protocol = "HTTPS", port = 443, default_server_group = "web" } } }
  expect_failures = [var.listeners]
}

run "unknown_default_server_group_rejected" {
  command = plan
  variables { listeners = { http = { protocol = "HTTP", port = 80, default_server_group = "nope" } } }
  expect_failures = [alicloud_alb_listener.this["http"]]
}

run "rule_without_condition_rejected" {
  command = plan
  variables { rules = { bad = { listener = "http", priority = 10, server_group = "web" } } }
  expect_failures = [var.rules]
}

run "rule_without_action_rejected" {
  command = plan
  variables { rules = { bad = { listener = "http", priority = 10, paths = ["/x"] } } }
  expect_failures = [var.rules]
}

run "rule_priority_zero_rejected" {
  command = plan
  variables { rules = { bad = { listener = "http", priority = 0, paths = ["/x"], server_group = "web" } } }
  expect_failures = [var.rules]
}

run "rule_unknown_listener_rejected" {
  command = plan
  variables { rules = { bad = { listener = "nope", priority = 10, paths = ["/x"], server_group = "web" } } }
  expect_failures = [alicloud_alb_rule.this["bad"]]
}

run "server_port_zero_rejected" {
  command = plan
  variables { server_groups = { web = { servers = [{ server_id = "i-a", port = 0 }] } } }
  expect_failures = [var.server_groups]
}

run "bad_scheduler_rejected" {
  command = plan
  variables { server_groups = { web = { scheduler = "Random" } } }
  expect_failures = [var.server_groups]
}

run "empty_edition_rejected" {
  command = plan
  variables { load_balancer_edition = "" }
  expect_failures = [var.load_balancer_edition]
}

run "bad_health_check_protocol_rejected" {
  command = plan
  variables { server_groups = { web = { health_check = { protocol = "UDP" } } } }
  expect_failures = [var.server_groups]
}

run "grpc_health_check_valid" {
  command = plan
  variables {
    server_groups = {
      web = { protocol = "GRPC", health_check = { protocol = "GRPC" }, servers = [{ server_id = "i-a", port = 8080 }] }
    }
  }

  assert {
    condition     = alicloud_alb_server_group.this["web"].protocol == "GRPC" && alicloud_alb_server_group.this["web"].health_check_config[0].health_check_protocol == "GRPC"
    error_message = "GRPC must pass through to server group and health check"
  }
}

run "mixed_case_grpc_health_check_rejected" {
  command = plan
  variables {
    server_groups = {
      web = { protocol = "GRPC", health_check = { protocol = "gRPC" }, servers = [{ server_id = "i-a", port = 8080 }] }
    }
  }
  expect_failures = [var.server_groups]
}

run "standard_edition_valid" {
  command = plan
  variables { load_balancer_edition = "StandardWithWaf" }

  assert {
    condition     = alicloud_alb_load_balancer.this.load_balancer_edition == "StandardWithWaf"
    error_message = "edition must pass through"
  }
}

run "bad_edition_rejected" {
  command = plan
  variables { load_balancer_edition = "Premium" }
  expect_failures = [var.load_balancer_edition]
}

run "sticky_off_still_sends_block" {
  command = plan

  assert {
    condition     = one(alicloud_alb_server_group.this["web"].sticky_session_config).sticky_session_enabled == false
    error_message = "sticky = false must send sticky_session_enabled = false"
  }
}

run "sticky_on_sends_insert" {
  command = plan
  variables {
    server_groups = { web = { sticky = true, servers = [{ server_id = "i-a", port = 8080 }] } }
  }

  assert {
    condition     = one(alicloud_alb_server_group.this["web"].sticky_session_config).sticky_session_enabled == true && one(alicloud_alb_server_group.this["web"].sticky_session_config).sticky_session_type == "Insert"
    error_message = "sticky = true must send Insert"
  }
}

run "no_server_group_rejected" {
  command = plan
  variables { server_groups = {} }
  expect_failures = [var.server_groups]
}

run "certificate_on_http_rejected" {
  command = plan
  variables { listeners = { http = { protocol = "HTTP", port = 80, default_server_group = "web", certificate_id = "cert-1" } } }
  expect_failures = [var.listeners]
}
