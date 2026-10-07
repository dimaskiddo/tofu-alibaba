mock_provider "alicloud" {}

variables {
  zones = ["ap-southeast-5a", "ap-southeast-5b"]
  tags  = { env = "stage" }
  groups = {
    vpc-1-c1-example-stage = {
      vpc_id         = "vpc-a"
      vpc_cidr_block = "10.0.0.0/16"
      subnets = [
        { name = "public-a-1-c1-example-stage", cidr_block = "10.0.0.0/24", zone_id = "ap-southeast-5a" },
        { name = "public-b-1-c1-example-stage", cidr_block = "10.0.1.0/24", zone_id = "ap-southeast-5b" },
      ]
    }
    vpc-2-c1-example-stage = {
      vpc_id         = "vpc-b"
      vpc_cidr_block = "10.100.0.0/16"
      subnets = [
        { name = "shared-a-2-c1-example-stage", cidr_block = "10.100.0.0/24", zone_id = "ap-southeast-5a", tags = { product = "hub" } },
        { name = "shared-b-2-c1-example-stage", cidr_block = "10.100.1.0/24", zone_id = "ap-southeast-5b" },
      ]
    }
  }
}

run "two_vpc_groups_merge_by_name" {
  command = plan

  assert {
    condition     = length(output.subnet_zones) == 4 && length(output.subnet_cidr_blocks) == 4 && output.subnet_cidr_blocks["shared-a-2-c1-example-stage"] == "10.100.0.0/24"
    error_message = "subnet outputs must merge the groups keyed by subnet name"
  }
}

run "duplicate_name_across_groups_rejected" {
  command = plan
  variables {
    groups = {
      vpc-1-c1-example-stage = {
        vpc_id         = "vpc-a"
        vpc_cidr_block = "10.0.0.0/16"
        subnets = [
          { name = "app-a", cidr_block = "10.0.0.0/24", zone_id = "ap-southeast-5a" },
          { name = "app-b", cidr_block = "10.0.1.0/24", zone_id = "ap-southeast-5b" },
        ]
      }
      vpc-2-c1-example-stage = {
        vpc_id         = "vpc-b"
        vpc_cidr_block = "10.100.0.0/16"
        subnets = [
          { name = "app-a", cidr_block = "10.100.0.0/24", zone_id = "ap-southeast-5a" },
          { name = "app-c", cidr_block = "10.100.1.0/24", zone_id = "ap-southeast-5b" },
        ]
      }
    }
  }
  expect_failures = [var.groups]
}

run "empty_groups_rejected" {
  command = plan
  variables { groups = {} }
  expect_failures = [var.groups]
}

run "empty_tags_rejected" {
  command = plan
  variables { tags = {} }
  expect_failures = [var.tags]
}

run "unknown_key_rejected" {
  command = plan
  variables {
    groups = { vpc-1-c1-example-stage = { vpc_id = "vpc-a", vpc_cidr_block = "10.0.0.0/16", vpcid = "typo", subnets = [{ name = "app-a", cidr_block = "10.0.0.0/24", zone_id = "ap-southeast-5a" }] } }
  }
  expect_failures = [var.groups]
}

run "nested_unknown_key_rejected" {
  command = plan
  variables {
    groups = { vpc-1-c1-example-stage = { vpc_id = "vpc-a", vpc_cidr_block = "10.0.0.0/16", subnets = [{ name = "app-a", cidr_block = "10.0.0.0/24", zone_id = "ap-southeast-5a", zone = "typo" }] } }
  }
  expect_failures = [var.groups]
}
