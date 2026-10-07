mock_provider "alicloud" {
  mock_data "alicloud_account" {
    defaults = { id = "100000000000000" }
  }
}

variables {
  tags = { env = "stage" }
  instances = {
    oss-1-c1-example-stage = { ram_user_id = "200000000000001", versioning = "Enabled" }
    oss-2-c1-example-stage = { ram_user_id = "200000000000002", visibility = "public", tags = { product = "logs" } }
  }
}

run "two_instances" {
  command = plan

  assert {
    condition     = length(output.instances) == 2 && contains(keys(output.instances), "oss-2-c1-example-stage")
    error_message = "each instance must produce its own keyed output"
  }

  assert {
    condition     = output.instances["oss-1-c1-example-stage"].visibility == "private" && output.instances["oss-2-c1-example-stage"].visibility == "public"
    error_message = "visibility must default to private and pass through per instance"
  }
}

run "tags_merged" {
  command = plan

  assert {
    condition     = output.instances["oss-1-c1-example-stage"].tags == tomap({ env = "stage" }) && output.instances["oss-2-c1-example-stage"].tags == tomap({ env = "stage", product = "logs" })
    error_message = "instance tags must merge over the shared tags"
  }
}

run "unknown_key_rejected" {
  command = plan
  variables {
    instances = {
      oss-1-c1-example-stage = { ram_user_id = "200000000000001", kms_key = "kms-1" }
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

run "nested_unknown_key_rejected" {
  command = plan
  variables {
    instances = { oss-1-c1-example-stage = { ram_user_id = "200000000000001", lifecycle_rules = [{ id = "a", prefx = "logs/", expiration_days = 30 }] } }
  }
  expect_failures = [var.instances]
}

run "null_lifecycle_rules_accepted" {
  command = plan
  variables {
    instances = {
      oss-1-c1-example-stage = { ram_user_id = "200000000000001", lifecycle_rules = null }
    }
  }

  assert {
    condition     = contains(keys(output.instances), "oss-1-c1-example-stage")
    error_message = "leaves pass omitted lifecycle_rules as null; the wrapper checks must accept it"
  }
}
