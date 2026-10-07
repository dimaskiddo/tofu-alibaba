mock_provider "alicloud" {}

variables {
  tags  = { env = "stage" }
  zones = ["ap-southeast-5a", "ap-southeast-5b"]
  instances = {
    clb-1-c1-example-stage = { address_type = "intranet", vswitch_id = "vsw-a", backend_servers = { main = { server_id = "i-1", port = 80 } }, listeners = { http = { protocol = "http", frontend_port = 80, bandwidth = -1 } } }
    clb-2-c1-example-stage = { address_type = "intranet", vswitch_id = "vsw-a", backend_servers = { main = { server_id = "i-1", port = 80 } }, listeners = { http = { protocol = "http", frontend_port = 80, bandwidth = -1 } } }
  }
}

run "two_instances" {
  command = plan

  assert {
    condition     = length(output.instances) == 2 && contains(keys(output.instances), "clb-2-c1-example-stage")
    error_message = "each instance must produce its own keyed output"
  }
}

run "tags_merged" {
  command = plan
  variables {
    instances = {
      clb-1-c1-example-stage = { address_type = "intranet", vswitch_id = "vsw-a", backend_servers = { main = { server_id = "i-1", port = 80 } }, listeners = { http = { protocol = "http", frontend_port = 80 } }, tags = { role = "web", env = "override" } }
    }
  }

  assert {
    condition     = output.instances["clb-1-c1-example-stage"].tags == tomap({ env = "override", role = "web" })
    error_message = "instance tags must merge over the shared tags, instance winning"
  }
}

run "unknown_key_rejected" {
  command = plan
  variables {
    instances = {
      clb-1-c1-example-stage = { vswitch_id = "vsw-a", listeners = { http = { protocol = "http", frontend_port = 80, backend_port = 80 } }, listener = {} }
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
    instances = { clb-1-c1-example-stage = { address_type = "intranet", vswitch_id = "vsw-a", backend_servers = { main = { server_id = "i-1", port = 80 } }, listeners = { http = { protocol = "http", frontend_port = 80, bandwith = -1 } } } }
  }
  expect_failures = [var.instances]
}
