mock_provider "alicloud" {}

variables {
  forward_table_id = "ftb-abc"
  tags             = { env = "stage" }
  entries = [
    { name = "ssh", external_ip = "203.0.113.10", external_port = "2222", internal_ip = "10.0.10.5", internal_port = "22" },
  ]
}

run "valid" {
  command = plan

  assert {
    condition     = alicloud_forward_entry.this["ssh"].external_port == "2222" && alicloud_forward_entry.this["ssh"].ip_protocol == "tcp"
    error_message = "entry must carry ports and default protocol tcp"
  }
}

run "range_valid" {
  command = plan
  variables {
    entries = [{ name = "rng", external_ip = "203.0.113.10", external_port = "10/20", internal_ip = "10.0.10.5", internal_port = "80/90", ip_protocol = "udp" }]
  }

  assert {
    condition     = length(alicloud_forward_entry.this) == 1
    error_message = "equal-size range must be accepted"
  }
}

run "any_valid" {
  command = plan
  variables {
    entries = [{ name = "ipmap", external_ip = "203.0.113.10", external_port = "any", internal_ip = "10.0.10.5", internal_port = "any", ip_protocol = "any" }]
  }

  assert {
    condition     = length(alicloud_forward_entry.this) == 1
    error_message = "IP mapping must be accepted"
  }
}

run "port_zero_rejected" {
  command = plan
  variables {
    entries = [{ name = "bad", external_ip = "203.0.113.10", external_port = "0", internal_ip = "10.0.10.5", internal_port = "22" }]
  }
  expect_failures = [var.entries]
}

run "port_65536_rejected" {
  command = plan
  variables {
    entries = [{ name = "bad", external_ip = "203.0.113.10", external_port = "2222", internal_ip = "10.0.10.5", internal_port = "65536" }]
  }
  expect_failures = [var.entries]
}

run "range_size_mismatch_rejected" {
  command = plan
  variables {
    entries = [{ name = "bad", external_ip = "203.0.113.10", external_port = "10/20", internal_ip = "10.0.10.5", internal_port = "80/95" }]
  }
  expect_failures = [var.entries]
}

run "reversed_range_rejected" {
  command = plan
  variables {
    entries = [{ name = "bad", external_ip = "203.0.113.10", external_port = "20/10", internal_ip = "10.0.10.5", internal_port = "20/10" }]
  }
  expect_failures = [var.entries]
}

run "any_with_numeric_port_rejected" {
  command = plan
  variables {
    entries = [{ name = "bad", external_ip = "203.0.113.10", external_port = "80", internal_ip = "10.0.10.5", internal_port = "80", ip_protocol = "any" }]
  }
  expect_failures = [var.entries]
}

run "missing_internal_ip_rejected" {
  command = plan
  variables {
    entries = [{ name = "bad", external_ip = "203.0.113.10", external_port = "80", internal_ip = "", internal_port = "80" }]
  }
  expect_failures = [var.entries]
}

run "bad_protocol_rejected" {
  command = plan
  variables {
    entries = [{ name = "bad", external_ip = "203.0.113.10", external_port = "80", internal_ip = "10.0.10.5", internal_port = "80", ip_protocol = "icmp" }]
  }
  expect_failures = [var.entries]
}

run "empty_tags_rejected" {
  command = plan
  variables { tags = {} }
  expect_failures = [var.tags]
}

run "bad_table_prefix_rejected" {
  command = plan
  variables { forward_table_id = "stb-abc" }
  expect_failures = [var.forward_table_id]
}

run "duplicate_external_mapping_rejected" {
  command = plan
  variables {
    entries = [
      { name = "ssh-a", external_ip = "203.0.113.10", external_port = "2222", internal_ip = "10.0.10.5", internal_port = "22" },
      { name = "ssh-b", external_ip = "203.0.113.10", external_port = "2222", internal_ip = "10.0.10.6", internal_port = "22" },
    ]
  }
  expect_failures = [var.entries]
}

run "same_port_other_protocol_valid" {
  command = plan
  variables {
    entries = [
      { name = "dns-t", external_ip = "203.0.113.10", external_port = "53", internal_ip = "10.0.10.5", internal_port = "53" },
      { name = "dns-u", external_ip = "203.0.113.10", external_port = "53", internal_ip = "10.0.10.5", internal_port = "53", ip_protocol = "udp" },
    ]
  }

  assert {
    condition     = length(alicloud_forward_entry.this) == 2
    error_message = "the same external port on tcp and udp is two distinct mappings"
  }
}

run "non_numeric_port_rejected" {
  command = plan
  variables {
    entries = [{ name = "bad", external_ip = "203.0.113.10", external_port = "http", internal_ip = "10.0.10.5", internal_port = "80" }]
  }
  expect_failures = [var.entries]
}

run "ipv6_external_ip_rejected" {
  command = plan
  variables {
    entries = [{ name = "bad", external_ip = "2001:db8::1", external_port = "80", internal_ip = "10.0.10.5", internal_port = "80" }]
  }
  expect_failures = [var.entries]
}

run "overlapping_ranges_rejected" {
  command = plan
  variables {
    entries = [
      { name = "aa", external_ip = "203.0.113.10", external_port = "10/20", internal_ip = "10.0.10.5", internal_port = "10/20" },
      { name = "bb", external_ip = "203.0.113.10", external_port = "15", internal_ip = "10.0.10.6", internal_port = "15" },
    ]
  }
  expect_failures = [var.entries]
}

run "same_port_other_protocol_accepted" {
  command = plan
  variables {
    entries = [
      { name = "aa", external_ip = "203.0.113.10", external_port = "53", internal_ip = "10.0.10.5", internal_port = "53", ip_protocol = "tcp" },
      { name = "bb", external_ip = "203.0.113.10", external_port = "53", internal_ip = "10.0.10.5", internal_port = "53", ip_protocol = "udp" },
    ]
  }

  assert {
    condition     = length(alicloud_forward_entry.this) == 2
    error_message = "tcp and udp on one port must not collide"
  }
}

run "any_shares_no_address_rejected" {
  command = plan
  variables {
    entries = [
      { name = "aa", external_ip = "203.0.113.10", external_port = "any", internal_ip = "10.0.10.5", internal_port = "any", ip_protocol = "any" },
      { name = "bb", external_ip = "203.0.113.10", external_port = "80", internal_ip = "10.0.10.6", internal_port = "80" },
    ]
  }
  expect_failures = [var.entries]
}
