mock_provider "alicloud" {}

variables {
  name = "ram-oss-1-c1-example-stage"
  tags = { env = "stage" }
}

run "defaults" {
  command = plan

  assert {
    condition     = alicloud_ram_user.this.name == "ram-oss-1-c1-example-stage" && alicloud_ram_user.this.tags["env"] == "stage"
    error_message = "user must carry the name and tags"
  }

  assert {
    condition     = alicloud_ram_access_key.this.user_name == "ram-oss-1-c1-example-stage"
    error_message = "one AccessKey must belong to the user"
  }
}

run "uppercase_name_rejected" {
  command = plan
  variables { name = "Ram-OSS" }
  expect_failures = [var.name]
}

run "short_name_rejected" {
  command = plan
  variables { name = "a" }
  expect_failures = [var.name]
}

run "empty_tags_rejected" {
  command = plan
  variables { tags = {} }
  expect_failures = [var.tags]
}

run "empty_tag_value_rejected" {
  command = plan
  variables { tags = { env = "" } }
  expect_failures = [var.tags]
}
