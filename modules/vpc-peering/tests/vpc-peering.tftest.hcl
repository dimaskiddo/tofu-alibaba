mock_provider "alicloud" {}

override_data {
  target = data.alicloud_regions.current
  values = {
    regions = [{ id = "ap-southeast-5", local_name = "Jakarta", region_id = "ap-southeast-5" }]
  }
}

variables {
  peer_name                = "peer-1-c1-example-stage"
  vpc_id                   = "vpc-aaa"
  vpc_cidr_block           = "10.0.0.0/16"
  accepting_vpc_id         = "vpc-bbb"
  accepting_vpc_cidr_block = "10.100.0.0/16"
  accepting_region_id      = "ap-southeast-5"
  tags                     = { env = "stage" }
}

run "valid" {
  command = plan

  assert {
    condition     = alicloud_vpc_peer_connection.this.tags["env"] == "stage" && alicloud_vpc_peer_connection.this.accepting_vpc_id == "vpc-bbb"
    error_message = "tags and accepter must propagate"
  }
}

run "no_routes_by_default" {
  command = plan

  assert {
    condition     = length(alicloud_route_entry.requester) == 0 && length(alicloud_route_entry.accepter) == 0
    error_message = "no route table given must mean no route entries"
  }
}

run "routes_both_sides" {
  command = plan
  variables {
    route_table_id           = "vtb-aaa"
    accepting_route_table_id = "vtb-bbb"
  }

  assert {
    condition     = alicloud_route_entry.requester[0].destination_cidrblock == "10.100.0.0/16" && alicloud_route_entry.requester[0].route_table_id == "vtb-aaa"
    error_message = "requester route must point at the accepter CIDR"
  }

  assert {
    condition     = alicloud_route_entry.accepter[0].destination_cidrblock == "10.0.0.0/16" && alicloud_route_entry.accepter[0].nexthop_type == "VpcPeer"
    error_message = "accepter route must point at the requester CIDR via VpcPeer"
  }
}

run "inter_region_accepter_route_rejected" {
  command = plan
  variables {
    accepting_region_id      = "cn-hangzhou"
    accepting_route_table_id = "vtb-bbb"
  }
  expect_failures = [alicloud_route_entry.accepter]
}

run "bad_route_table_id_rejected" {
  command = plan
  variables { route_table_id = "rtb-aaa" }
  expect_failures = [var.route_table_id]
}

run "inter_region_options_pass_through" {
  command = plan
  variables {
    accepting_region_id = "cn-hangzhou"
    bandwidth           = 100
    link_type           = "Platinum"
  }

  assert {
    condition     = alicloud_vpc_peer_connection.this.bandwidth == 100 && alicloud_vpc_peer_connection.this.link_type == "Platinum"
    error_message = "bandwidth and link_type must propagate"
  }
}

run "overlapping_cidr_rejected" {
  command = plan
  variables { accepting_vpc_cidr_block = "10.0.1.0/24" }
  expect_failures = [var.accepting_vpc_cidr_block]
}

run "same_vpc_rejected" {
  command = plan
  variables { accepting_vpc_id = "vpc-aaa" }
  expect_failures = [var.accepting_vpc_id]
}

run "bad_region_rejected" {
  command = plan
  variables { accepting_region_id = "Singapore" }
  expect_failures = [var.accepting_region_id]
}

run "zero_bandwidth_rejected" {
  command = plan
  variables { bandwidth = 0 }
  expect_failures = [var.bandwidth]
}

run "bad_link_type_rejected" {
  command = plan
  variables { link_type = "Silver" }
  expect_failures = [var.link_type]
}

run "empty_tags_rejected" {
  command = plan
  variables { tags = {} }
  expect_failures = [var.tags]
}

run "cross_account_requester_route_rejected" {
  command = plan
  variables {
    accepting_ali_uid = 1234567890123456
    route_table_id    = "vtb-aaa"
  }
  expect_failures = [alicloud_route_entry.requester]
}

run "cross_account_accepter_route_rejected" {
  command = plan
  variables {
    accepting_ali_uid        = 1234567890123456
    accepting_route_table_id = "vtb-bbb"
  }
  expect_failures = [alicloud_route_entry.accepter]
}

run "intra_region_bandwidth_rejected" {
  command = plan
  variables { bandwidth = 100 }
  expect_failures = [alicloud_vpc_peer_connection.this]
}

run "intra_region_link_type_rejected" {
  command = plan
  variables { link_type = "Gold" }
  expect_failures = [alicloud_vpc_peer_connection.this]
}

run "peer_name_116_chars_rejected" {
  command = plan
  variables { peer_name = "abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbc" }
  expect_failures = [var.peer_name]
}

run "peer_name_115_chars_valid" {
  command = plan
  variables { peer_name = "abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbc" }

  assert {
    condition     = length(alicloud_vpc_peer_connection.this.peer_connection_name) == 115
    error_message = "a 115 char peer_name must be accepted"
  }
}

run "host_bits_cidr_rejected" {
  command = plan
  variables { vpc_cidr_block = "10.0.0.1/16" }
  expect_failures = [var.vpc_cidr_block]
}

run "ipv6_accepting_cidr_rejected" {
  command = plan
  variables { accepting_vpc_cidr_block = "2001:db8::/32" }
  expect_failures = [var.accepting_vpc_cidr_block]
}
