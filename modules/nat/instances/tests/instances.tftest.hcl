mock_provider "alicloud" {}

variables {
  tags = { env = "stage" }
  instances = {
    nat-1-c1-example-stage = { network_type = "internet", vpc_id = "vpc-a", vswitch_id = "vsw-a", eip_allocation_ids = { e1 = "eip-1" } }
    nat-2-c1-example-stage = { network_type = "intranet", vpc_id = "vpc-a", vpc_cidr_block = "10.0.0.0/16", vswitch_id = "vsw-a", nat_ip_cidr = "10.100.250.0/24", nat_ips = { transit-1 = { ip = "10.100.250.10" } }, route_table_id = "vtb-a" }
  }
}

run "two_instances" {
  command = plan

  assert {
    condition     = length(output.instances) == 2 && contains(keys(output.instances), "nat-2-c1-example-stage")
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
      nat-1-c1-example-stage = { network_type = "internet", vpc_id = "vpc-a", vswitch_id = "vsw-a", eip_allocation_ids = { e1 = "eip-1" }, tags = { product = "hub" } }
      nat-2-c1-example-stage = { network_type = "internet", vpc_id = "vpc-a", vswitch_id = "vsw-a", eip_allocation_ids = { e2 = "eip-2" } }
    }
  }

  assert {
    condition     = output.instances["nat-1-c1-example-stage"].tags == tomap({ env = "stage", product = "hub" }) && output.instances["nat-2-c1-example-stage"].tags == tomap({ env = "stage" })
    error_message = "per-instance tags must merge over the shared tags without leaking to siblings"
  }
}

run "unknown_key_rejected" {
  command = plan
  variables {
    instances = {
      nat-1-c1-example-stage = { network_type = "internet", vpc_id = "vpc-a", vswitch_id = "vsw-a", eip_allocation_ids = { e1 = "eip-1" }, vswitch = "typo" }
    }
  }
  expect_failures = [var.instances]
}
