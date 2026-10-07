mock_provider "alicloud" {}

variables {
  tags = { env = "stage" }
  instances = {
    sg-1-c1-example-stage = { vpc_id = "vpc-abc", rules = [{ name = "ssh", type = "ingress", ip_protocol = "tcp", port_range = "22/22", cidr_ip = "10.0.0.0/16" }] }
    sg-2-c1-example-stage = { vpc_id = "vpc-abc", rules = [{ name = "ssh", type = "ingress", ip_protocol = "tcp", port_range = "22/22", cidr_ip = "10.0.0.0/16" }] }
  }
}

run "two_instances" {
  command = plan

  assert {
    condition     = length(output.instances) == 2 && contains(keys(output.instances), "sg-2-c1-example-stage")
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
      sg-1-c1-example-stage = { vpc_id = "vpc-abc", rules = [{ name = "ssh", type = "ingress", ip_protocol = "tcp", port_range = "22/22", cidr_ip = "10.0.0.0/16" }], tags = { product = "hub" } }
      sg-2-c1-example-stage = { vpc_id = "vpc-abc", rules = [{ name = "ssh", type = "ingress", ip_protocol = "tcp", port_range = "22/22", cidr_ip = "10.0.0.0/16" }] }
    }
  }

  assert {
    condition     = output.instances["sg-1-c1-example-stage"].tags == tomap({ env = "stage", product = "hub" }) && output.instances["sg-2-c1-example-stage"].tags == tomap({ env = "stage" })
    error_message = "per-instance tags must merge over the shared tags without leaking to siblings"
  }
}

run "unknown_key_rejected" {
  command = plan
  variables {
    instances = {
      sg-1-c1-example-stage = { vpc_id = "vpc-abc", rules = [], rule = "typo" }
    }
  }
  expect_failures = [var.instances]
}
