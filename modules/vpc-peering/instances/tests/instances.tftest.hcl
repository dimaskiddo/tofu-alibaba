mock_provider "alicloud" {}

variables {
  tags = { env = "stage" }
  instances = {
    peer-1-c1-example-stage = { vpc_id = "vpc-a", vpc_cidr_block = "10.0.0.0/16", accepting_vpc_id = "vpc-b", accepting_vpc_cidr_block = "10.100.0.0/16", accepting_region_id = "ap-southeast-5" }
    peer-2-c1-example-stage = { vpc_id = "vpc-a", vpc_cidr_block = "10.0.0.0/16", accepting_vpc_id = "vpc-b", accepting_vpc_cidr_block = "10.100.0.0/16", accepting_region_id = "ap-southeast-5" }
  }
}

run "two_instances" {
  command = plan

  assert {
    condition     = length(output.instances) == 2 && contains(keys(output.instances), "peer-2-c1-example-stage")
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
      peer-1-c1-example-stage = { vpc_id = "vpc-a", vpc_cidr_block = "10.0.0.0/16", accepting_vpc_id = "vpc-b", accepting_vpc_cidr_block = "10.100.0.0/16", accepting_region_id = "ap-southeast-5", tags = { product = "hub" } }
      peer-2-c1-example-stage = { vpc_id = "vpc-a", vpc_cidr_block = "10.0.0.0/16", accepting_vpc_id = "vpc-b", accepting_vpc_cidr_block = "10.100.0.0/16", accepting_region_id = "ap-southeast-5" }
    }
  }

  assert {
    condition     = output.instances["peer-1-c1-example-stage"].tags == tomap({ env = "stage", product = "hub" }) && output.instances["peer-2-c1-example-stage"].tags == tomap({ env = "stage" })
    error_message = "per-instance tags must merge over the shared tags without leaking to siblings"
  }
}

run "unknown_key_rejected" {
  command = plan
  variables {
    instances = {
      peer-1-c1-example-stage = { vpc_id = "vpc-a", vpc_cidr_block = "10.0.0.0/16", accepting_vpc_id = "vpc-b", accepting_vpc_cidr_block = "10.100.0.0/16", accepting_region_id = "ap-southeast-5", region = "typo" }
    }
  }
  expect_failures = [var.instances]
}
