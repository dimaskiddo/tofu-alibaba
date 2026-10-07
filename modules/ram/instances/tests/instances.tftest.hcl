mock_provider "alicloud" {}

variables {
  tags = { env = "stage" }
  instances = {
    ram-oss-1-c1-example-stage = {}
    ram-oss-2-c1-example-stage = { tags = { product = "logs" } }
  }
}

run "two_instances" {
  command = plan

  assert {
    condition     = length(output.instances) == 2 && contains(keys(output.instances), "ram-oss-2-c1-example-stage")
    error_message = "each instance must produce its own keyed output"
  }

  assert {
    condition     = !contains(keys(output.instances["ram-oss-1-c1-example-stage"]), "generated_passwords")
    error_message = "secrets must not be inside the instances output"
  }
}

run "tags_merged" {
  command = plan

  assert {
    condition     = output.instances["ram-oss-1-c1-example-stage"].tags == tomap({ env = "stage" }) && output.instances["ram-oss-2-c1-example-stage"].tags == tomap({ env = "stage", product = "logs" })
    error_message = "instance tags must merge over the shared tags"
  }
}

run "unknown_key_rejected" {
  command = plan
  variables {
    instances = {
      ram-oss-1-c1-example-stage = { comment = "typo" }
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
