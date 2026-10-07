mock_provider "alicloud" {}

variables {
  tags = { env = "stage" }
}

run "create_mode" {
  command = plan
  variables {
    vpc_id           = "vpc-aaa"
    route_table_name = "rt-1-c1-example-stage"
    vswitch_ids      = { a = "vsw-a", b = "vsw-b" }
    routes = {
      to-hub = { destination_cidrblock = "10.100.0.0/16", nexthop_type = "VpcPeer", nexthop_id = "pcc-abc" }
    }
  }

  assert {
    condition     = length(alicloud_route_table.this) == 1 && alicloud_route_table.this[0].tags["env"] == "stage"
    error_message = "create mode must create one tagged route table"
  }

  assert {
    condition     = output.tags["env"] == "stage"
    error_message = "create mode must expose the table tags"
  }

  assert {
    condition     = length(alicloud_route_table_attachment.this) == 2 && length(alicloud_route_entry.this) == 1
    error_message = "vSwitches and routes must be created"
  }

  assert {
    condition     = alicloud_route_entry.this["to-hub"].name == "to-hub" && alicloud_route_entry.this["to-hub"].nexthop_type == "VpcPeer"
    error_message = "route name and next hop type must propagate"
  }
}

run "existing_mode" {
  command = plan
  variables {
    route_table_id = "vtb-abc"
    routes = {
      to-hub = { destination_cidrblock = "10.100.0.0/16", nexthop_type = "VpcPeer", nexthop_id = "pcc-abc" }
    }
  }

  assert {
    condition     = length(alicloud_route_table.this) == 0 && alicloud_route_entry.this["to-hub"].route_table_id == "vtb-abc"
    error_message = "existing mode must reuse the given table and create none"
  }

  assert {
    condition     = output.tags == null
    error_message = "existing mode tags nothing, so the tags output must be null"
  }
}

run "existing_with_vswitches_rejected" {
  command = plan
  variables {
    route_table_id = "vtb-abc"
    vswitch_ids    = { a = "vsw-a" }
    routes = {
      to-hub = { destination_cidrblock = "10.100.0.0/16", nexthop_type = "VpcPeer", nexthop_id = "pcc-abc" }
    }
  }
  expect_failures = [var.vswitch_ids]
}

run "existing_without_routes_rejected" {
  command = plan
  variables { route_table_id = "vtb-abc" }
  expect_failures = [var.routes]
}

run "create_without_vpc_rejected" {
  command = plan
  variables { route_table_name = "rt-1-c1-example-stage" }
  expect_failures = [var.vpc_id]
}

run "create_without_name_rejected" {
  command = plan
  variables { vpc_id = "vpc-aaa" }
  expect_failures = [var.route_table_name]
}

run "bad_nexthop_type_rejected" {
  command = plan
  variables {
    route_table_id = "vtb-abc"
    routes = {
      rt = { destination_cidrblock = "10.100.0.0/16", nexthop_type = "Teleporter", nexthop_id = "x-1" }
    }
  }
  expect_failures = [var.routes]
}

run "bad_cidr_rejected" {
  command = plan
  variables {
    route_table_id = "vtb-abc"
    routes = {
      rt = { destination_cidrblock = "10.100.0.0/33", nexthop_type = "VpcPeer", nexthop_id = "pcc-abc" }
    }
  }
  expect_failures = [var.routes]
}

run "duplicate_destination_rejected" {
  command = plan
  variables {
    route_table_id = "vtb-abc"
    routes = {
      a = { destination_cidrblock = "10.100.0.0/16", nexthop_type = "VpcPeer", nexthop_id = "pcc-abc" }
      b = { destination_cidrblock = "10.100.0.0/16", nexthop_type = "NatGateway", nexthop_id = "ngw-abc" }
    }
  }
  expect_failures = [var.routes]
}

run "empty_tags_rejected" {
  command = plan
  variables {
    tags           = {}
    route_table_id = "vtb-abc"
    routes = {
      rt = { destination_cidrblock = "10.100.0.0/16", nexthop_type = "VpcPeer", nexthop_id = "pcc-abc" }
    }
  }
  expect_failures = [var.tags]
}

run "bad_route_key_rejected" {
  command = plan
  variables {
    route_table_id = "vtb-abc"
    routes = {
      "Bad_Key" = { destination_cidrblock = "10.100.0.0/16", nexthop_type = "VpcPeer", nexthop_id = "pcc-abc" }
    }
  }
  expect_failures = [var.routes]
}

run "existing_with_description_rejected" {
  command = plan
  variables {
    route_table_id = "vtb-abc"
    description    = "ignored"
    routes = {
      to-hub = { destination_cidrblock = "10.100.0.0/16", nexthop_type = "VpcPeer", nexthop_id = "pcc-abc" }
    }
  }
  expect_failures = [var.description]
}

run "host_bits_destination_rejected" {
  command = plan
  variables {
    route_table_id = "vtb-abc"
    routes = {
      to-hub = { destination_cidrblock = "10.100.0.1/16", nexthop_type = "VpcPeer", nexthop_id = "pcc-abc" }
    }
  }
  expect_failures = [var.routes]
}

run "ipv6_destination_rejected" {
  command = plan
  variables {
    route_table_id = "vtb-abc"
    routes = {
      to-hub = { destination_cidrblock = "2001:db8::/32", nexthop_type = "VpcPeer", nexthop_id = "pcc-abc" }
    }
  }
  expect_failures = [var.routes]
}
