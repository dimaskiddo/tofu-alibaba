mock_provider "alicloud" {}

variables {
  name       = "main-1-c1-example-stage"
  zones      = ["ap-southeast-5a", "ap-southeast-5b"]
  vswitch_id = "vsw-a"
  tags       = { env = "stage" }
  backend_servers = {
    "main-1-c1-example-stage" = { server_id = "i-a", port = 8080 }
  }
  listeners = {
    http = { protocol = "http", frontend_port = 80 }
  }
}

run "valid_with_servers" {
  command = plan

  assert {
    condition     = length(alicloud_slb_server_group.this) == 1 && length(alicloud_slb_server_group_server_attachment.this) == 1 && length(alicloud_slb_listener.this) == 1
    error_message = "LB, server group, attachment and listener must be planned"
  }

  assert {
    condition     = alicloud_slb_load_balancer.this.tags["env"] == "stage" && alicloud_slb_load_balancer.this.address_type == "intranet"
    error_message = "tags and address type must propagate"
  }
}

run "valid_without_servers_uses_backend_port" {
  command = plan
  variables {
    backend_servers = {}
    listeners       = { tcp = { protocol = "tcp", frontend_port = 22, backend_port = 22 } }
  }

  assert {
    condition     = length(alicloud_slb_server_group.this) == 0 && alicloud_slb_listener.this["tcp"].backend_port == 22
    error_message = "without servers the listener must use backend_port"
  }
}

run "valid_zones" {
  command = plan
  variables {
    master_zone_id = "ap-southeast-5a"
    slave_zone_id  = "ap-southeast-5b"
  }

  assert {
    condition     = alicloud_slb_load_balancer.this.slave_zone_id == "ap-southeast-5b"
    error_message = "registered zones must be accepted"
  }
}

run "tcp_and_udp_same_port_valid" {
  command = plan
  variables {
    listeners = {
      dns-tcp = { protocol = "tcp", frontend_port = 53 }
      dns-udp = { protocol = "udp", frontend_port = 53 }
    }
  }

  assert {
    condition     = length(alicloud_slb_listener.this) == 2
    error_message = "tcp and udp may share a port number"
  }
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

run "master_zone_not_registered_rejected" {
  command = plan
  variables { master_zone_id = "ap-southeast-5c" }
  expect_failures = [alicloud_slb_load_balancer.this]
}

run "same_master_slave_rejected" {
  command = plan
  variables {
    master_zone_id = "ap-southeast-5a"
    slave_zone_id  = "ap-southeast-5a"
  }
  expect_failures = [alicloud_slb_load_balancer.this]
}

run "intranet_without_vswitch_rejected" {
  command = plan
  variables { vswitch_id = null }
  expect_failures = [var.vswitch_id]
}

run "pay_by_bandwidth_rejected" {
  command = plan
  variables {
    address_type         = "internet"
    vswitch_id           = null
    internet_charge_type = "PayByBandwidth"
  }
  expect_failures = [var.internet_charge_type]
}

run "frontend_port_zero_rejected" {
  command = plan
  variables { listeners = { bad = { protocol = "http", frontend_port = 0 } } }
  expect_failures = [var.listeners]
}

run "frontend_port_65536_rejected" {
  command = plan
  variables { listeners = { bad = { protocol = "http", frontend_port = 65536 } } }
  expect_failures = [var.listeners]
}

run "duplicate_frontend_port_rejected" {
  command = plan
  variables {
    listeners = {
      a = { protocol = "http", frontend_port = 80 }
      b = { protocol = "tcp", frontend_port = 80 }
    }
  }
  expect_failures = [var.listeners]
}

run "bad_protocol_rejected" {
  command = plan
  variables { listeners = { bad = { protocol = "icmp", frontend_port = 80 } } }
  expect_failures = [var.listeners]
}

run "https_without_certificate_rejected" {
  command = plan
  variables { listeners = { bad = { protocol = "https", frontend_port = 443 } } }
  expect_failures = [var.listeners]
}

run "no_backend_target_rejected" {
  command = plan
  variables {
    backend_servers = {}
    listeners       = { http = { protocol = "http", frontend_port = 80 } }
  }
  expect_failures = [alicloud_slb_listener.this["http"]]
}

run "backend_server_port_zero_rejected" {
  command = plan
  variables { backend_servers = { "main-1-c1-example-stage" = { server_id = "i-a", port = 0 } } }
  expect_failures = [var.backend_servers]
}

run "http_sch_scheduler_rejected" {
  command = plan
  variables { listeners = { bad = { protocol = "http", frontend_port = 80, scheduler = "sch" } } }
  expect_failures = [var.listeners]
}

run "tcp_qch_scheduler_rejected" {
  command = plan
  variables { listeners = { bad = { protocol = "tcp", frontend_port = 80, scheduler = "qch" } } }
  expect_failures = [var.listeners]
}

run "tcp_sch_and_udp_qch_valid" {
  command = plan
  variables {
    listeners = {
      tcp-a = { protocol = "tcp", frontend_port = 80, scheduler = "sch" }
      udp-b = { protocol = "udp", frontend_port = 53, scheduler = "qch" }
    }
  }

  assert {
    condition     = alicloud_slb_listener.this["tcp-a"].scheduler == "sch" && alicloud_slb_listener.this["udp-b"].scheduler == "qch"
    error_message = "protocol-specific schedulers must pass through"
  }
}

run "bandwidth_set_rejected" {
  command = plan
  variables {
    address_type = "internet"
    vswitch_id   = null
    bandwidth    = 10
  }
  expect_failures = [var.bandwidth]
}
