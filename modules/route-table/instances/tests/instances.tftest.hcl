mock_provider "alicloud" {}

variables {
  tags = { env = "stage" }
  instances = {
    rt-1-c1-example-stage = { route_table_id = "vtb-a", routes = { to-hub = { destination_cidrblock = "10.100.0.0/16", nexthop_type = "VpcPeer", nexthop_id = "pcc-1" } } }
    rt-2-c1-example-stage = { route_table_id = "vtb-a", routes = { to-hub = { destination_cidrblock = "10.100.0.0/16", nexthop_type = "VpcPeer", nexthop_id = "pcc-1" } } }
  }
}

run "two_instances" {
  command = plan

  assert {
    condition     = length(output.instances) == 2 && contains(keys(output.instances), "rt-2-c1-example-stage")
    error_message = "each instance must produce its own keyed output"
  }
}

run "empty_instances_rejected" {
  command = plan
  variables { instances = {} }
  expect_failures = [var.instances]
}

run "empty_tags_rejected" {
  command = plan
  variables { tags = {} }
  expect_failures = [var.tags]
}

run "tags_merge_over_shared" {
  command = plan
  variables {
    instances = {
      rt-1-c1-example-stage = { vpc_id = "vpc-a", route_table_name = "rt-1-c1-example-stage", tags = { product = "hub" } }
      rt-2-c1-example-stage = { vpc_id = "vpc-b", route_table_name = "rt-2-c1-example-stage" }
    }
  }

  assert {
    condition     = output.instances["rt-1-c1-example-stage"].tags == tomap({ env = "stage", product = "hub" }) && output.instances["rt-2-c1-example-stage"].tags == tomap({ env = "stage" })
    error_message = "per-instance tags must merge over the shared tags without leaking to siblings"
  }
}

run "unknown_key_rejected" {
  command = plan
  variables {
    instances = {
      rt-1-c1-example-stage = { route_table_id = "vtb-a", routes = { to-hub = { destination_cidrblock = "10.100.0.0/16", nexthop_type = "VpcPeer", nexthop_id = "pcc-1" } }, route = "typo" }
    }
  }
  expect_failures = [var.instances]
}
