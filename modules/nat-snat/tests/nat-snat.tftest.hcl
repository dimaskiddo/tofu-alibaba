mock_provider "alicloud" {}

variables {
  snat_table_id = "stb-abc"
  snat_ips      = ["203.0.113.10"]
  tags          = { env = "stage" }
  entries = [
    { name = "snat-a", source_vswitch_id = "vsw-a" },
    { name = "snat-b", source_cidr = "10.0.20.0/24" },
  ]
}

run "valid" {
  command = plan

  assert {
    condition     = length(alicloud_snat_entry.this) == 2 && alicloud_snat_entry.this["snat-a"].snat_ip == "203.0.113.10"
    error_message = "both entries must use the given snat_ip"
  }
}

run "multiple_ips_joined" {
  command = plan
  variables { snat_ips = ["203.0.113.10", "203.0.113.11"] }

  assert {
    condition     = alicloud_snat_entry.this["snat-a"].snat_ip == "203.0.113.10,203.0.113.11"
    error_message = "multiple IPs must be comma separated"
  }
}

run "missing_source_rejected" {
  command = plan
  variables { entries = [{ name = "snat-a" }] }
  expect_failures = [var.entries]
}

run "both_sources_rejected" {
  command = plan
  variables { entries = [{ name = "snat-a", source_cidr = "10.0.0.0/24", source_vswitch_id = "vsw-a" }] }
  expect_failures = [var.entries]
}

run "invalid_cidr_rejected" {
  command = plan
  variables { entries = [{ name = "snat-a", source_cidr = "10.0.0.0/40" }] }
  expect_failures = [var.entries]
}

run "empty_snat_ips_rejected" {
  command = plan
  variables { snat_ips = [] }
  expect_failures = [var.snat_ips]
}

run "invalid_snat_ip_rejected" {
  command = plan
  variables { snat_ips = ["not-an-ip"] }
  expect_failures = [var.snat_ips]
}

run "empty_table_id_rejected" {
  command = plan
  variables { snat_table_id = "" }
  expect_failures = [var.snat_table_id]
}

run "empty_tags_rejected" {
  command = plan
  variables { tags = {} }
  expect_failures = [var.tags]
}

run "bad_table_prefix_rejected" {
  command = plan
  variables { snat_table_id = "ftb-abc" }
  expect_failures = [var.snat_table_id]
}

run "duplicate_vswitch_rejected" {
  command = plan
  variables {
    entries = [
      { name = "snat-a", source_vswitch_id = "vsw-a" },
      { name = "snat-b", source_vswitch_id = "vsw-a" },
    ]
  }
  expect_failures = [var.entries]
}

run "duplicate_cidr_rejected" {
  command = plan
  variables {
    entries = [
      { name = "snat-a", source_cidr = "10.0.20.0/24" },
      { name = "snat-b", source_cidr = "10.0.20.0/24" },
    ]
  }
  expect_failures = [var.entries]
}

run "host_bits_cidr_rejected" {
  command = plan
  variables { entries = [{ name = "snat-a", source_cidr = "10.0.20.5/24" }] }
  expect_failures = [var.entries]
}

run "ipv6_snat_ip_rejected" {
  command = plan
  variables { snat_ips = ["2001:db8::1"] }
  expect_failures = [var.snat_ips]
}

run "duplicate_snat_ips_rejected" {
  command = plan
  variables { snat_ips = ["203.0.113.10", "203.0.113.10"] }
  expect_failures = [var.snat_ips]
}
