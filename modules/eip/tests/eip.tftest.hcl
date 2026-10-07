mock_provider "alicloud" {}

variables {
  tags = { env = "stage" }
  eips = [
    { name = "nat-1-c1-example-stage" },
    { name = "bastion-1-c1-example-stage", bandwidth = 10, instance_id = "i-abc" },
  ]
}

run "valid" {
  command = plan

  assert {
    condition     = length(alicloud_eip_address.this) == 2 && length(alicloud_eip_association.this) == 1
    error_message = "two EIPs, one association expected"
  }

  assert {
    condition     = alicloud_eip_address.this["nat-1-c1-example-stage"].tags["env"] == "stage" && alicloud_eip_address.this["bastion-1-c1-example-stage"].bandwidth == "10"
    error_message = "tags and bandwidth must propagate"
  }
}

run "empty_eips_rejected" {
  command = plan
  variables { eips = [] }
  expect_failures = [var.eips]
}

run "empty_tags_rejected" {
  command = plan
  variables { tags = {} }
  expect_failures = [var.tags]
}

run "bandwidth_zero_rejected" {
  command = plan
  variables { eips = [{ name = "nat-1-c1-example-stage", bandwidth = 0 }] }
  expect_failures = [var.eips]
}

run "traffic_bandwidth_over_200_rejected" {
  command = plan
  variables { eips = [{ name = "nat-1-c1-example-stage", bandwidth = 201 }] }
  expect_failures = [var.eips]
}

run "pay_by_bandwidth_rejected" {
  command = plan
  variables { eips = [{ name = "nat-1-c1-example-stage", bandwidth = 10, internet_charge_type = "PayByBandwidth" }] }
  expect_failures = [var.eips]
}

run "association_prefix_rejected" {
  command = plan
  variables { eips = [{ name = "nat-1-c1-example-stage", instance_id = "lb-abc" }] }
  expect_failures = [var.eips]
}

run "tags_output_merges_member_tags" {
  command = plan
  variables { eips = [{ name = "nat-1-c1-example-stage", tags = { product = "snat" } }] }

  assert {
    condition     = output.tags["nat-1-c1-example-stage"]["product"] == "snat" && output.tags["nat-1-c1-example-stage"]["env"] == "stage"
    error_message = "tags output must hold the shared and member tags"
  }
}

run "bad_charge_type_rejected" {
  command = plan
  variables { eips = [{ name = "nat-1-c1-example-stage", internet_charge_type = "Free" }] }
  expect_failures = [var.eips]
}

run "duplicate_name_rejected" {
  command = plan
  variables { eips = [{ name = "a-1" }, { name = "a-1" }] }
  expect_failures = [var.eips]
}

run "charge_types_propagate" {
  command = plan
  variables {
    eips = [
      { name = "snat-1-c1-example-stage", bandwidth = 100, internet_charge_type = "PayByTraffic", isp = "BGP_PRO" },
      { name = "dnat-1-c1-example-stage", bandwidth = 200, internet_charge_type = "PayByTraffic" },
      { name = "default-1-c1-example-stage" },
    ]
  }

  assert {
    condition     = alicloud_eip_address.this["snat-1-c1-example-stage"].isp == "BGP_PRO" && alicloud_eip_address.this["dnat-1-c1-example-stage"].internet_charge_type == "PayByTraffic" && alicloud_eip_address.this["default-1-c1-example-stage"].internet_charge_type == "PayByTraffic"
    error_message = "isp must propagate and the charge type is PayByTraffic"
  }
}

run "member_tags_do_not_leak" {
  command = plan
  variables {
    eips = [
      { name = "nat-1-c1-example-stage", tags = { product = "snat" } },
      { name = "bastion-1-c1-example-stage" },
    ]
  }

  assert {
    condition     = alicloud_eip_address.this["nat-1-c1-example-stage"].tags["product"] == "snat" && !contains(keys(alicloud_eip_address.this["bastion-1-c1-example-stage"].tags), "product")
    error_message = "member tags must apply to that EIP only, on top of the shared tags"
  }
}

run "empty_member_tag_rejected" {
  command = plan
  variables {
    eips = [{ name = "nat-1-c1-example-stage", tags = { product = "" } }]
  }
  expect_failures = [var.eips]
}

run "association_instance_types" {
  command = plan
  variables {
    eips = [
      { name = "ecs-1-c1-example-stage", instance_id = "i-abc" },
      { name = "eni-1-c1-example-stage", instance_id = "eni-abc" },
      { name = "havip-1-c1-example-stage", instance_id = "havip-abc" },
    ]
  }

  assert {
    condition     = alicloud_eip_association.this["eni-1-c1-example-stage"].instance_type == "NetworkInterface" && alicloud_eip_association.this["havip-1-c1-example-stage"].instance_type == "HaVip"
    error_message = "ENI and HAVIP IDs must set the matching instance_type"
  }
}

run "ngw_instance_rejected" {
  command = plan
  variables { eips = [{ name = "nat-1-c1-example-stage", instance_id = "ngw-abc" }] }
  expect_failures = [var.eips]
}
