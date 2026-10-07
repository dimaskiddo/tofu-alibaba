mock_provider "alicloud" {}

variables {
  name             = "kms-1-c1-example-stage"
  dkms_instance_id = "kst-abc"
  tags             = { env = "stage" }
}

run "defaults" {
  command = plan

  assert {
    condition     = alicloud_kms_alias.this.alias_name == "alias/kms-1-c1-example-stage" && alicloud_kms_key.this.key_spec == "Aliyun_AES_256"
    error_message = "alias must be alias/<name> and the spec AES-256"
  }

  assert {
    condition     = alicloud_kms_key.this.automatic_rotation == "Enabled" && alicloud_kms_key.this.rotation_interval == "31536000s" && alicloud_kms_key.this.deletion_protection == "Disabled"
    error_message = "rotation on and deletion protection off by default"
  }

  assert {
    condition     = alicloud_kms_key.this.tags["env"] == "stage" && alicloud_kms_key.this.dkms_instance_id == "kst-abc"
    error_message = "tags and KMS instance must pass through"
  }
}

run "rotation_off" {
  command = plan
  variables {
    rotation_interval   = null
    deletion_protection = true
  }

  assert {
    condition     = alicloud_kms_key.this.automatic_rotation == "Disabled" && alicloud_kms_key.this.deletion_protection == "Enabled"
    error_message = "null rotation_interval must disable rotation; an explicit true must enable protection"
  }
}

run "bad_name_rejected" {
  command = plan
  variables { name = "Bad_Name" }
  expect_failures = [var.name]
}

run "empty_instance_rejected" {
  command = plan
  variables { dkms_instance_id = "" }
  expect_failures = [var.dkms_instance_id]
}

run "pending_window_6_rejected" {
  command = plan
  variables { pending_window_in_days = 6 }
  expect_failures = [var.pending_window_in_days]
}

run "rotation_year_unit_rejected" {
  command = plan
  variables { rotation_interval = "1y" }
  expect_failures = [var.rotation_interval]
}

run "asymmetric_spec_rejected" {
  command = plan
  variables { key_spec = "RSA_2048" }
  expect_failures = [var.key_spec]
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

run "rotation_1d_rejected" {
  command = plan
  variables { rotation_interval = "1d" }
  expect_failures = [var.rotation_interval]
}

run "rotation_400d_rejected" {
  command = plan
  variables { rotation_interval = "400d" }
  expect_failures = [var.rotation_interval]
}

run "rotation_range_edges_valid" {
  command = plan
  variables { rotation_interval = "604800s" }

  assert {
    condition     = alicloud_kms_key.this.rotation_interval == "604800s"
    error_message = "7 days in seconds must be accepted"
  }
}

run "rotation_8760h_valid" {
  command = plan
  variables { rotation_interval = "8760h" }

  assert {
    condition     = alicloud_kms_key.this.rotation_interval == "31536000s"
    error_message = "365 days in hours must be accepted"
  }
}

run "rotation_over_a_year_in_seconds_rejected" {
  command = plan
  variables { rotation_interval = "31536001s" }
  expect_failures = [var.rotation_interval]
}
