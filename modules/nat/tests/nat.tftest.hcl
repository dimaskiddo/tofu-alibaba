mock_provider "alicloud" {}

variables {
  nat_name   = "nat-1-c1-example-stage"
  vpc_id     = "vpc-abc"
  vswitch_id = "vsw-abc"
  tags       = { env = "stage" }
}

run "internet_valid" {
  command = plan
  variables {
    eip_allocation_ids = { nat-1-c1-example-stage = "eip-abc" }
  }

  assert {
    condition     = alicloud_nat_gateway.this.network_type == "internet" && length(alicloud_eip_association.this) == 1 && length(alicloud_vpc_nat_ip.this) == 0
    error_message = "internet NAT must associate EIPs and create no NAT IP"
  }

  assert {
    condition     = alicloud_nat_gateway.this.tags["env"] == "stage"
    error_message = "tags must propagate"
  }
}

run "intranet_valid" {
  command = plan
  variables {
    network_type   = "intranet"
    vpc_cidr_block = "10.0.0.0/16"
    nat_ip_cidr    = "172.16.0.0/24"
    nat_ips = {
      snat-ip = { ip = "172.16.0.10" }
      dnat-ip = { ip = null }
    }
    route_table_id = "vtb-abc"
  }

  assert {
    condition     = length(alicloud_vpc_nat_ip_cidr.this) == 1 && length(alicloud_eip_association.this) == 0
    error_message = "intranet NAT must create a NAT IP CIDR and no EIP association"
  }

  assert {
    condition     = length(alicloud_vpc_nat_ip.this) == 2 && alicloud_vpc_nat_ip.this["snat-ip"].nat_ip == "172.16.0.10"
    error_message = "each nat_ips entry must create a NAT IP and keep a pinned address"
  }

  assert {
    condition     = length(alicloud_route_entry.nat_ip_cidr) == 1 && alicloud_route_entry.nat_ip_cidr["172.16.0.0/24"].nexthop_type == "NatGateway"
    error_message = "NAT IP CIDR must be routed to the NAT gateway"
  }
}

run "intranet_without_nat_ips_rejected" {
  command = plan
  variables {
    network_type   = "intranet"
    vpc_cidr_block = "10.0.0.0/16"
    nat_ip_cidr    = "172.16.0.0/24"
    route_table_id = "vtb-abc"
  }
  expect_failures = [var.nat_ips]
}

run "internet_with_nat_ips_rejected" {
  command = plan
  variables {
    eip_allocation_ids = { a = "eip-abc" }
    nat_ips            = { a-ip = { ip = null } }
  }
  expect_failures = [var.nat_ips]
}

run "nat_ip_outside_cidr_rejected" {
  command = plan
  variables {
    network_type   = "intranet"
    vpc_cidr_block = "10.0.0.0/16"
    nat_ip_cidr    = "172.16.0.0/24"
    nat_ips        = { snat-ip = { ip = "172.17.0.10" } }
    route_table_id = "vtb-abc"
  }
  expect_failures = [var.nat_ips]
}

run "intranet_without_route_table_rejected" {
  command = plan
  variables {
    network_type   = "intranet"
    vpc_cidr_block = "10.0.0.0/16"
    nat_ip_cidr    = "172.16.0.0/24"
    nat_ips        = { snat-ip = { ip = null } }
  }
  expect_failures = [var.route_table_id]
}

run "internet_without_eip_rejected" {
  command         = plan
  expect_failures = [var.eip_allocation_ids]
}

run "intranet_with_eip_rejected" {
  command = plan
  variables {
    network_type       = "intranet"
    vpc_cidr_block     = "10.0.0.0/16"
    nat_ip_cidr        = "172.16.0.0/24"
    nat_ips            = { snat-ip = { ip = null } }
    route_table_id     = "vtb-abc"
    eip_allocation_ids = { a = "eip-abc" }
  }
  expect_failures = [var.eip_allocation_ids]
}

run "intranet_without_cidr_rejected" {
  command = plan
  variables {
    network_type   = "intranet"
    vpc_cidr_block = "10.0.0.0/16"
    nat_ips        = { snat-ip = { ip = null } }
    route_table_id = "vtb-abc"
  }
  expect_failures = [var.nat_ip_cidr]
}

run "intranet_cidr_overlaps_vpc_rejected" {
  command = plan
  variables {
    network_type   = "intranet"
    vpc_cidr_block = "10.0.0.0/16"
    nat_ip_cidr    = "10.0.1.0/24"
    nat_ips        = { snat-ip = { ip = null } }
    route_table_id = "vtb-abc"
  }
  expect_failures = [var.nat_ip_cidr]
}

run "intranet_cidr_public_range_rejected" {
  command = plan
  variables {
    network_type   = "intranet"
    vpc_cidr_block = "10.0.0.0/16"
    nat_ip_cidr    = "8.8.8.0/24"
    nat_ips        = { snat-ip = { ip = null } }
    route_table_id = "vtb-abc"
  }
  expect_failures = [var.nat_ip_cidr]
}

run "intranet_cidr_short_mask_rejected" {
  command = plan
  variables {
    network_type   = "intranet"
    vpc_cidr_block = "10.0.0.0/16"
    nat_ip_cidr    = "172.16.0.0/12"
    nat_ips        = { snat-ip = { ip = null } }
    route_table_id = "vtb-abc"
  }
  expect_failures = [var.nat_ip_cidr]
}

run "intranet_missing_vpc_cidr_rejected" {
  command = plan
  variables {
    network_type   = "intranet"
    nat_ip_cidr    = "172.16.0.0/24"
    nat_ips        = { snat-ip = { ip = null } }
    route_table_id = "vtb-abc"
  }
  expect_failures = [var.vpc_cidr_block]
}

run "bad_network_type_rejected" {
  command = plan
  variables { network_type = "public" }
  expect_failures = [var.network_type]
}

run "empty_tags_rejected" {
  command = plan
  variables {
    tags               = {}
    eip_allocation_ids = { a = "eip-abc" }
  }
  expect_failures = [var.tags]
}

run "internet_with_nat_ip_cidr_rejected" {
  command = plan
  variables {
    eip_allocation_ids = { a = "eip-abc" }
    nat_ip_cidr        = "172.16.0.0/24"
  }
  expect_failures = [var.nat_ip_cidr]
}

run "internet_with_route_table_rejected" {
  command = plan
  variables {
    eip_allocation_ids = { a = "eip-abc" }
    route_table_id     = "vtb-abc"
  }
  expect_failures = [var.route_table_id]
}

run "bad_eip_prefix_rejected" {
  command = plan
  variables { eip_allocation_ids = { a = "abc" } }
  expect_failures = [var.eip_allocation_ids]
}

run "bad_route_table_prefix_rejected" {
  command = plan
  variables {
    network_type   = "intranet"
    vpc_cidr_block = "10.0.0.0/16"
    nat_ip_cidr    = "172.16.0.0/24"
    nat_ips        = { snat-ip = { ip = null } }
    route_table_id = "rtb-abc"
  }
  expect_failures = [var.route_table_id]
}

run "duplicate_pinned_ip_rejected" {
  command = plan
  variables {
    network_type   = "intranet"
    vpc_cidr_block = "10.0.0.0/16"
    nat_ip_cidr    = "172.16.0.0/24"
    nat_ips = {
      snat-ip = { ip = "172.16.0.10" }
      dnat-ip = { ip = "172.16.0.10" }
    }
    route_table_id = "vtb-abc"
  }
  expect_failures = [var.nat_ips]
}

run "ipv6_vpc_cidr_rejected" {
  command = plan
  variables {
    network_type   = "intranet"
    vpc_cidr_block = "2001:db8::/32"
    nat_ip_cidr    = "172.16.0.0/24"
    nat_ips        = { snat-ip = { ip = null } }
    route_table_id = "vtb-abc"
  }
  expect_failures = [var.vpc_cidr_block]
}

run "host_bits_nat_ip_cidr_rejected" {
  command = plan
  variables {
    network_type   = "intranet"
    vpc_cidr_block = "10.0.0.0/16"
    nat_ip_cidr    = "172.16.0.5/24"
    nat_ips        = { snat-ip = { ip = null } }
    route_table_id = "vtb-abc"
  }
  expect_failures = [var.nat_ip_cidr]
}
