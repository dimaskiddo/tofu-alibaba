mock_provider "alicloud" {}

override_data {
  target = module.this.data.alicloud_regions.current
  values = {
    regions = [{ id = "ap-southeast-5", local_name = "Jakarta", region_id = "ap-southeast-5" }]
  }
}

override_data {
  target = module.this.data.alicloud_cen_transit_router_route_tables.system
  values = {
    tables = [{ id = "tr-mock:vtb-mock", transit_router_route_table_id = "vtb-mock" }]
  }
}

variables {
  zones = ["ap-southeast-5a", "ap-southeast-5b"]
  tags  = { env = "stage" }
  instances = {
    cen-1-c1-example-stage = {
      vpc_attachments = {
        tra-1-c1-example-stage = { vpc_id = "vpc-a", zone_mappings = [{ vswitch_id = "vsw-a", zone_id = "ap-southeast-5a" }, { vswitch_id = "vsw-b", zone_id = "ap-southeast-5b" }] }
      }
    }
    cen-2-c1-example-stage = {
      vpc_attachments = {
        tra-2-c1-example-stage = { vpc_id = "vpc-b", zone_mappings = [{ vswitch_id = "vsw-c", zone_id = "ap-southeast-5a" }, { vswitch_id = "vsw-d", zone_id = "ap-southeast-5b" }] }
      }
    }
  }
}

run "two_instances" {
  command = plan

  assert {
    condition     = length(output.instances) == 2 && contains(keys(output.instances), "cen-2-c1-example-stage")
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

run "empty_zones_rejected" {
  command = plan
  variables { zones = [] }
  expect_failures = [var.zones]
}

run "tags_merge_over_shared" {
  command = plan
  variables {
    instances = {
      cen-1-c1-example-stage = {
        tags = { product = "hub" }
        vpc_attachments = {
          tra-1-c1-example-stage = { vpc_id = "vpc-a", zone_mappings = [{ vswitch_id = "vsw-a", zone_id = "ap-southeast-5a" }, { vswitch_id = "vsw-b", zone_id = "ap-southeast-5b" }] }
        }
      }
      cen-2-c1-example-stage = {
        vpc_attachments = {
          tra-2-c1-example-stage = { vpc_id = "vpc-b", zone_mappings = [{ vswitch_id = "vsw-c", zone_id = "ap-southeast-5a" }, { vswitch_id = "vsw-d", zone_id = "ap-southeast-5b" }] }
        }
      }
    }
  }

  assert {
    condition     = output.instances["cen-1-c1-example-stage"].tags == tomap({ env = "stage", product = "hub" }) && output.instances["cen-2-c1-example-stage"].tags == tomap({ env = "stage" })
    error_message = "per-instance tags must merge over the shared tags without leaking to siblings"
  }
}

run "unknown_key_rejected" {
  command = plan
  variables {
    instances = { cen-1-c1-example-stage = { bogus = true } }
  }
  expect_failures = [var.instances]
}

run "nested_unknown_key_rejected" {
  command = plan
  variables {
    instances = {
      cen-1-c1-example-stage = {
        vpc_attachments = { tra-1-c1-example-stage = { vpc_id = "vpc-a", zone_mappings = [], bogus = true } }
      }
    }
  }
  expect_failures = [var.instances]
}

run "duplicate_attachment_name_rejected" {
  command = plan
  variables {
    instances = {
      cen-1-c1-example-stage = {
        vpc_attachments = { tra-1-c1-example-stage = { vpc_id = "vpc-a", zone_mappings = [{ vswitch_id = "vsw-a", zone_id = "ap-southeast-5a" }, { vswitch_id = "vsw-b", zone_id = "ap-southeast-5b" }] } }
      }
      cen-2-c1-example-stage = {
        vpc_attachments = { tra-1-c1-example-stage = { vpc_id = "vpc-b", zone_mappings = [{ vswitch_id = "vsw-c", zone_id = "ap-southeast-5a" }, { vswitch_id = "vsw-d", zone_id = "ap-southeast-5b" }] } }
      }
    }
  }
  expect_failures = [var.instances]
}
