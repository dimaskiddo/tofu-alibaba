mock_provider "alicloud" {}

variables {
  tags  = { env = "stage" }
  zones = ["ap-southeast-5a", "ap-southeast-5b"]
  instances = {
    alb-1-c1-example-stage = { vpc_id = "vpc-abc", load_balancer_edition = "Basic", zone_mappings = [{ zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" }, { zone_id = "ap-southeast-5b", vswitch_id = "vsw-b" }], server_groups = { web = { servers = [{ server_id = "i-1", port = 80 }] } }, listeners = { http = { protocol = "HTTP", port = 80, default_server_group = "web" } } }
    alb-2-c1-example-stage = { vpc_id = "vpc-abc", load_balancer_edition = "Basic", zone_mappings = [{ zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" }, { zone_id = "ap-southeast-5b", vswitch_id = "vsw-b" }], server_groups = { web = { servers = [{ server_id = "i-1", port = 80 }] } }, listeners = { http = { protocol = "HTTP", port = 80, default_server_group = "web" } } }
  }
}

run "two_instances" {
  command = plan

  assert {
    condition     = length(output.instances) == 2 && contains(keys(output.instances), "alb-2-c1-example-stage")
    error_message = "each instance must produce its own keyed output"
  }
}

run "tags_merged" {
  command = plan
  variables {
    instances = {
      alb-1-c1-example-stage = { vpc_id = "vpc-abc", load_balancer_edition = "Basic", zone_mappings = [{ zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" }, { zone_id = "ap-southeast-5b", vswitch_id = "vsw-b" }], server_groups = { web = { servers = [{ server_id = "i-1", port = 80 }] } }, listeners = { http = { protocol = "HTTP", port = 80, default_server_group = "web" } }, tags = { role = "web", env = "override" } }
    }
  }

  assert {
    condition     = output.instances["alb-1-c1-example-stage"].tags == tomap({ env = "override", role = "web" })
    error_message = "instance tags must merge over the shared tags, instance winning"
  }
}

run "unknown_key_rejected" {
  command = plan
  variables {
    instances = {
      alb-1-c1-example-stage = { vpc_id = "vpc-abc", load_balancer_edition = "Basic", zone_mappings = [{ zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" }, { zone_id = "ap-southeast-5b", vswitch_id = "vsw-b" }], listeners = { http = { protocol = "HTTP", port = 80, default_server_group = "web" } }, server_group = {} }
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
    instances = { alb-1-c1-example-stage = { vpc_id = "vpc-abc", load_balancer_edition = "Basic", zone_mappings = [{ zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" }, { zone_id = "ap-southeast-5b", vswitch_id = "vsw-b" }], server_groups = { web = { health_check = { pth = "/" }, servers = [{ server_id = "i-1", port = 80 }] } }, listeners = { http = { protocol = "HTTP", port = 80, default_server_group = "web" } } } }
  }
  expect_failures = [var.instances]
}

run "null_rules_accepted" {
  command = plan
  variables {
    instances = {
      alb-1-c1-example-stage = { vpc_id = "vpc-abc", load_balancer_edition = "Basic", zone_mappings = [{ zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" }, { zone_id = "ap-southeast-5b", vswitch_id = "vsw-b" }], server_groups = { web = { servers = [{ server_id = "i-1", port = 80 }] } }, listeners = { http = { protocol = "HTTP", port = 80, default_server_group = "web" } }, rules = null }
    }
  }

  assert {
    condition     = contains(keys(output.instances), "alb-1-c1-example-stage")
    error_message = "leaves pass omitted rules as null; the wrapper checks must accept it"
  }
}
