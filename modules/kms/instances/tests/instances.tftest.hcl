mock_provider "alicloud" {}

variables {
  tags = { env = "stage" }
  instances = {
    kms-1-c1-example-stage = { dkms_instance_id = "kst-abc" }
    kms-2-c1-example-stage = { dkms_instance_id = "kst-abc", rotation_interval = null }
  }
}

run "two_instances" {
  command = plan

  assert {
    condition     = length(output.instances) == 2 && contains(keys(output.instances), "kms-2-c1-example-stage")
    error_message = "each instance must produce its own keyed output"
  }
}

run "default_rotation_and_null_disable" {
  command = plan

  assert {
    condition     = output.instances["kms-1-c1-example-stage"].rotation_interval == "31536000s" && output.instances["kms-2-c1-example-stage"].rotation_interval == null && output.instances["kms-2-c1-example-stage"].automatic_rotation == "Disabled" && output.instances["kms-1-c1-example-stage"].automatic_rotation == "Enabled"
    error_message = "an omitted rotation_interval must default to 365d (read back in seconds) and an explicit null must disable rotation"
  }
}

run "instance_tag_wins_over_shared" {
  command = plan
  variables {
    instances = {
      kms-1-c1-example-stage = { dkms_instance_id = "kst-abc", tags = { role = "disk", env = "override" } }
    }
  }

  assert {
    condition     = output.instances["kms-1-c1-example-stage"].tags == tomap({ env = "override", role = "disk" })
    error_message = "instance tags must merge over the shared tags, instance winning"
  }
}

run "unknown_key_rejected" {
  command = plan
  variables {
    instances = {
      kms-1-c1-example-stage = { dkms_instance_id = "kst-abc", rotation = "30d" }
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
