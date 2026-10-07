mock_provider "alicloud" {}

variables {
  tags = { env = "stage" }
  instances = {
    dnat-1-c1-example-stage = { forward_table_id = "ftb-1", entries = [{ name = "http", external_ip = "203.0.113.11", external_port = "80", internal_ip = "10.0.0.1", internal_port = "80" }] }
    dnat-2-c1-example-stage = { forward_table_id = "ftb-1", entries = [{ name = "http", external_ip = "203.0.113.11", external_port = "8080", internal_ip = "10.0.0.1", internal_port = "80" }] }
  }
}

run "two_instances" {
  command = plan

  assert {
    condition     = length(output.instances) == 2 && contains(keys(output.instances), "dnat-2-c1-example-stage")
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

run "unknown_key_rejected" {
  command = plan
  variables {
    instances = {
      dnat-1-c1-example-stage = { forward_table_id = "ftb-1", entries = [{ name = "http", external_ip = "203.0.113.11", external_port = "80", internal_ip = "10.0.0.1", internal_port = "80" }], table = "typo" }
    }
  }
  expect_failures = [var.instances]
}

run "cross_instance_overlap_rejected" {
  command = plan
  variables {
    instances = {
      dnat-1-c1-example-stage = { forward_table_id = "ftb-1", entries = [{ name = "http", external_ip = "203.0.113.11", external_port = "80", internal_ip = "10.0.0.1", internal_port = "80" }] }
      dnat-2-c1-example-stage = { forward_table_id = "ftb-1", entries = [{ name = "web", external_ip = "203.0.113.11", external_port = "70/90", internal_ip = "10.0.0.2", internal_port = "70/90" }] }
    }
  }
  expect_failures = [var.instances]
}
