mock_provider "alicloud" {}

variables {
  vpc_name   = "vpc-1-c1-example-stage"
  cidr_block = "10.0.0.0/16"
  tags       = { env = "stage" }
}

run "valid" {
  command = plan

  assert {
    condition     = alicloud_vpc.this.tags["env"] == "stage" && alicloud_vpc.this.cidr_block == "10.0.0.0/16"
    error_message = "tags and cidr must propagate to the VPC"
  }

  assert {
    condition     = output.tags["env"] == "stage"
    error_message = "the tags output must expose the VPC tags"
  }
}

run "empty_tags_rejected" {
  command = plan
  variables { tags = {} }
  expect_failures = [var.tags]
}

run "empty_tag_value_rejected" {
  command = plan
  variables { tags = { env = "" } }
  expect_failures = [var.tags]
}

run "invalid_cidr_rejected" {
  command = plan
  variables { cidr_block = "10.0.0.0/33" }
  expect_failures = [var.cidr_block]
}

run "invalid_name_rejected" {
  command = plan
  variables { vpc_name = "Bad_Name" }
  expect_failures = [var.vpc_name]
}

run "ipv6_cidr_rejected" {
  command = plan
  variables { cidr_block = "2001:db8::/32" }
  expect_failures = [var.cidr_block]
}

run "host_bits_cidr_rejected" {
  command = plan
  variables { cidr_block = "10.0.0.1/16" }
  expect_failures = [var.cidr_block]
}

run "mask_too_wide_rejected" {
  command = plan
  variables { cidr_block = "10.0.0.0/15" }
  expect_failures = [var.cidr_block]
}

run "mask_too_narrow_rejected" {
  command = plan
  variables { cidr_block = "10.0.0.0/29" }
  expect_failures = [var.cidr_block]
}

run "mask_28_accepted" {
  command = plan
  variables { cidr_block = "10.0.0.0/28" }
}
