mock_provider "alicloud" {}

variables {
  vpc_id         = "vpc-abc"
  vpc_cidr_block = "10.0.0.0/16"
  zones          = ["ap-southeast-5a", "ap-southeast-5b"]
  tags           = { env = "stage" }
  subnets = [
    { name = "app-a", cidr_block = "10.0.10.0/24", zone_id = "ap-southeast-5a" },
    { name = "app-b", cidr_block = "10.0.20.0/24", zone_id = "ap-southeast-5b" },
  ]
}

run "multi_zone" {
  command = plan

  assert {
    condition     = length(alicloud_vswitch.this) == 2 && alicloud_vswitch.this["app-b"].zone_id == "ap-southeast-5b"
    error_message = "every declared subnet must be created in its zone"
  }

  assert {
    condition     = output.subnet_cidr_blocks["app-a"] == "10.0.10.0/24" && output.subnet_cidr_blocks["app-b"] == "10.0.20.0/24"
    error_message = "subnet_cidr_blocks must expose each subnet CIDR by name"
  }

  assert {
    condition     = length(output.subnet_zones) == length(output.subnet_ids) && alltrue([for k, z in output.subnet_zones : z != ""])
    error_message = "subnet_zones must expose a zone for every subnet"
  }
}

run "single_zone" {
  command = plan
  variables {
    zones   = ["ap-southeast-5a"]
    subnets = [{ name = "app-a", cidr_block = "10.0.10.0/24", zone_id = "ap-southeast-5a" }]
  }

  assert {
    condition     = length(alicloud_vswitch.this) == 1
    error_message = "single zone must work"
  }
}

run "empty_zones_rejected" {
  command = plan
  variables { zones = [] }
  expect_failures = [var.zones]
}

run "empty_tags_rejected" {
  command = plan
  variables { tags = {} }
  expect_failures = [var.tags]
}

run "zone_not_registered_rejected" {
  command = plan
  variables {
    subnets = [
      { name = "app-a", cidr_block = "10.0.10.0/24", zone_id = "ap-southeast-5a" },
      { name = "app-b", cidr_block = "10.0.20.0/24", zone_id = "ap-southeast-5c" },
    ]
  }
  expect_failures = [var.subnets]
}

run "overlap_rejected" {
  command = plan
  variables {
    subnets = [
      { name = "app-a", cidr_block = "10.0.10.0/24", zone_id = "ap-southeast-5a" },
      { name = "app-b", cidr_block = "10.0.10.128/25", zone_id = "ap-southeast-5b" },
    ]
  }
  expect_failures = [var.subnets]
}

run "outside_vpc_rejected" {
  command = plan
  variables {
    subnets = [
      { name = "app-a", cidr_block = "10.0.10.0/24", zone_id = "ap-southeast-5a" },
      { name = "app-b", cidr_block = "192.168.0.0/24", zone_id = "ap-southeast-5b" },
    ]
  }
  expect_failures = [var.subnets]
}

run "invalid_cidr_rejected" {
  command = plan
  variables {
    subnets = [
      { name = "app-a", cidr_block = "10.0.10.0/24", zone_id = "ap-southeast-5a" },
      { name = "app-b", cidr_block = "nope", zone_id = "ap-southeast-5b" },
    ]
  }
  expect_failures = [var.subnets]
}

run "member_tags_do_not_leak" {
  command = plan
  variables {
    subnets = [
      { name = "app-a", cidr_block = "10.0.10.0/24", zone_id = "ap-southeast-5a", tags = { product = "hub" } },
      { name = "app-b", cidr_block = "10.0.20.0/24", zone_id = "ap-southeast-5b" },
    ]
  }

  assert {
    condition     = alicloud_vswitch.this["app-a"].tags["product"] == "hub" && !contains(keys(alicloud_vswitch.this["app-b"].tags), "product") && alicloud_vswitch.this["app-b"].tags["env"] == "stage"
    error_message = "member tags must apply to that subnet only, on top of the shared tags"
  }
}

run "empty_member_tag_rejected" {
  command = plan
  variables {
    subnets = [
      { name = "app-a", cidr_block = "10.0.10.0/24", zone_id = "ap-southeast-5a", tags = { product = "" } },
      { name = "app-b", cidr_block = "10.0.20.0/24", zone_id = "ap-southeast-5b" },
    ]
  }
  expect_failures = [var.subnets]
}

run "missing_zone_rejected" {
  command = plan
  variables {
    subnets = [
      { name = "app-a", cidr_block = "10.0.10.0/24", zone_id = "ap-southeast-5a" },
      { name = "app-b", cidr_block = "10.0.20.0/24", zone_id = "" },
    ]
  }
  expect_failures = [var.subnets]
}

run "unhosted_zone_rejected" {
  command = plan
  variables {
    subnets = [
      { name = "app-a", cidr_block = "10.0.10.0/24", zone_id = "ap-southeast-5a" },
      { name = "app-b", cidr_block = "10.0.20.0/24", zone_id = "ap-southeast-5a" },
    ]
  }
  expect_failures = [var.subnets]
}

run "ipv6_cidr_rejected" {
  command = plan
  variables {
    subnets = [
      { name = "app-a", cidr_block = "10.0.10.0/24", zone_id = "ap-southeast-5a" },
      { name = "app-b", cidr_block = "2001:db8::/64", zone_id = "ap-southeast-5b" },
    ]
  }
  expect_failures = [var.subnets]
}

run "host_bits_cidr_rejected" {
  command = plan
  variables {
    subnets = [
      { name = "app-a", cidr_block = "10.0.10.0/24", zone_id = "ap-southeast-5a" },
      { name = "app-b", cidr_block = "10.0.20.5/24", zone_id = "ap-southeast-5b" },
    ]
  }
  expect_failures = [var.subnets]
}

run "host_bits_vpc_cidr_rejected" {
  command = plan
  variables { vpc_cidr_block = "10.0.0.1/16" }
  expect_failures = [var.vpc_cidr_block]
}

run "mask_30_rejected" {
  command = plan
  variables {
    zones   = ["ap-southeast-5a"]
    subnets = [{ name = "app-a", cidr_block = "10.0.10.0/30", zone_id = "ap-southeast-5a" }]
  }
  expect_failures = [var.subnets]
}

run "mask_29_accepted" {
  command = plan
  variables {
    zones   = ["ap-southeast-5a"]
    subnets = [{ name = "app-a", cidr_block = "10.0.10.0/29", zone_id = "ap-southeast-5a" }]
  }
}
