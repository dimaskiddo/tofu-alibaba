mock_provider "alicloud" {}

variables {
  tags = { env = "stage" }
  instances = {
    cbwp-1-c1-example-stage = { bandwidth = 20 }
    cbwp-2-c1-example-stage = { bandwidth = 50, tags = { product = "logs" }, eip_ids = { eip-a = "eip-1" } }
  }
}

run "two_instances" {
  command = plan

  assert {
    condition     = length(output.instances) == 2 && contains(keys(output.instances), "cbwp-2-c1-example-stage")
    error_message = "each instance must produce its own keyed output"
  }

  assert {
    condition     = output.instances["cbwp-2-c1-example-stage"].eip_names == tolist(["eip-a"])
    error_message = "eip_ids must reach the module"
  }
}

run "tags_merged" {
  command = plan

  assert {
    condition     = output.instances["cbwp-1-c1-example-stage"].tags == tomap({ env = "stage" }) && output.instances["cbwp-2-c1-example-stage"].tags == tomap({ env = "stage", product = "logs" })
    error_message = "instance tags must merge over the shared tags"
  }
}

run "unknown_key_rejected" {
  command = plan
  variables {
    instances = {
      cbwp-1-c1-example-stage = { bandwidth = 20, bandwith = 5 }
    }
  }
  expect_failures = [var.instances]
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
