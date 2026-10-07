mock_provider "alicloud" {}

variables {
  tags = { env = "stage" }
  instances = {
    snat-1-c1-example-stage = { snat_table_id = "stb-1", snat_ips = ["203.0.113.10"], entries = [{ name = "snat-a", source_vswitch_id = "vsw-a" }] }
    snat-2-c1-example-stage = { snat_table_id = "stb-1", snat_ips = ["203.0.113.10"], entries = [{ name = "snat-b", source_vswitch_id = "vsw-b" }] }
  }
}

run "two_instances" {
  command = plan

  assert {
    condition     = length(output.instances) == 2 && contains(keys(output.instances), "snat-2-c1-example-stage")
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
      snat-1-c1-example-stage = { snat_table_id = "stb-1", snat_ips = ["203.0.113.10"], entries = [{ name = "snat-a", source_vswitch_id = "vsw-a" }], snat_ip = "typo" }
    }
  }
  expect_failures = [var.instances]
}

run "duplicate_source_on_one_table_rejected" {
  command = plan
  variables {
    instances = {
      snat-1-c1-example-stage = { snat_table_id = "stb-1", snat_ips = ["203.0.113.10"], entries = [{ name = "snat-a", source_vswitch_id = "vsw-a" }] }
      snat-2-c1-example-stage = { snat_table_id = "stb-1", snat_ips = ["203.0.113.11"], entries = [{ name = "snat-b", source_vswitch_id = "vsw-a" }] }
    }
  }
  expect_failures = [var.instances]
}
