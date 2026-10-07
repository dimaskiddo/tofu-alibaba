mock_provider "alicloud" {}

variables {
  instances = {
    vpc-1-c1-example-stage = { cidr_block = "10.0.0.0/16" }
    vpc-2-c1-example-stage = { cidr_block = "10.100.0.0/16", tags = { product = "hub" } }
  }
  tags = { env = "stage" }
}

run "two_vpcs" {
  command = plan

  assert {
    condition     = length(module.this) == 2 && module.this["vpc-2-c1-example-stage"].cidr_block == "10.100.0.0/16"
    error_message = "each instance must produce its own VPC keyed by name"
  }
}

run "member_tags_stay_on_their_vpc" {
  command = plan

  assert {
    condition     = output.instances["vpc-2-c1-example-stage"].tags["product"] == "hub" && !contains(keys(output.instances["vpc-1-c1-example-stage"].tags), "product")
    error_message = "per-instance tags must merge over the shared tags without leaking to siblings"
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

run "unknown_key_rejected" {
  command = plan
  variables {
    instances = { vpc-1-c1-example-stage = { cidr_block = "10.0.0.0/16", descripton = "typo" } }
  }
  expect_failures = [var.instances]
}
