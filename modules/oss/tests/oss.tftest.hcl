mock_provider "alicloud" {}

variables {
  name        = "oss-1-c1-example-stage"
  ram_user_id = "200000000000000"
  tags        = { env = "stage" }
}

override_data {
  target = data.alicloud_account.current
  values = { id = "100000000000000" }
}

run "defaults" {
  command = plan

  assert {
    condition     = alicloud_oss_bucket_acl.this.acl == "private" && alicloud_oss_bucket_public_access_block.this.block_public_access == true
    error_message = "bucket must be private with public access blocked by default"
  }

  assert {
    condition     = time_sleep.bucket_ready.create_duration == "30s"
    error_message = "ACL, block and policy must wait 30s after the bucket exists"
  }

  assert {
    condition     = join(",", jsondecode(alicloud_oss_bucket_policy.this.policy).Statement[0].Principal) == "200000000000000"
    error_message = "policy must grant only the RAM user, never *"
  }

  assert {
    condition     = join(",", jsondecode(alicloud_oss_bucket_policy.this.policy).Statement[0].Resource) == "acs:oss:*:100000000000000:oss-1-c1-example-stage,acs:oss:*:100000000000000:oss-1-c1-example-stage/*"
    error_message = "policy must cover the bucket and its objects"
  }

  assert {
    condition     = !contains(jsondecode(alicloud_oss_bucket_policy.this.policy).Statement[0].Action, "oss:PutBucketAcl") && !contains(jsondecode(alicloud_oss_bucket_policy.this.policy).Statement[0].Action, "oss:PutBucketPolicy")
    error_message = "policy must not grant bucket admin actions"
  }

  assert {
    condition     = one(alicloud_oss_bucket.this.server_side_encryption_rule).sse_algorithm == "AES256" && alicloud_oss_bucket.this.tags["env"] == "stage"
    error_message = "AES256 encryption and tags must be set by default"
  }

  assert {
    condition     = alicloud_oss_bucket.this.storage_class == "Standard" && alicloud_oss_bucket.this.redundancy_type == "LRS" && alicloud_oss_bucket.this.force_destroy == false
    error_message = "Standard, LRS and no force_destroy are the defaults"
  }
}

run "versioning_and_lifecycle" {
  command = plan
  variables {
    versioning = "Enabled"
    lifecycle_rules = [
      { id = "abort-mpu", abort_multipart_upload_days = 7 },
      { id = "logs", prefix = "logs/", transitions = [{ days = 30, storage_class = "IA" }], expiration_days = 365 },
    ]
  }

  assert {
    condition     = one(alicloud_oss_bucket.this.versioning).status == "Enabled" && length(alicloud_oss_bucket.this.lifecycle_rule) == 2
    error_message = "versioning and both lifecycle rules must be rendered"
  }
}

run "kms_encryption" {
  command = plan
  variables {
    sse_algorithm     = "KMS"
    kms_master_key_id = "key-abc"
  }

  assert {
    condition     = one(alicloud_oss_bucket.this.server_side_encryption_rule).kms_master_key_id == "key-abc"
    error_message = "KMS key must pass through"
  }
}

run "public_bucket" {
  command = plan
  variables { visibility = "public" }

  assert {
    condition     = alicloud_oss_bucket_acl.this.acl == "public-read" && alicloud_oss_bucket_public_access_block.this.block_public_access == false
    error_message = "public bucket must have the block off and ACL public-read"
  }

  assert {
    condition     = join(",", jsondecode(alicloud_oss_bucket_policy.this.policy).Statement[0].Principal) == "200000000000000"
    error_message = "public bucket policy still grants only the RAM user"
  }
}

run "bad_visibility_rejected" {
  command = plan
  variables { visibility = "public-read-write" }
  expect_failures = [var.visibility]
}

run "bad_ram_user_id_rejected" {
  command = plan
  variables { ram_user_id = "ram-user" }
  expect_failures = [var.ram_user_id]
}

run "uppercase_name_rejected" {
  command = plan
  variables { name = "Bad-Name" }
  expect_failures = [var.name]
}

run "short_name_rejected" {
  command = plan
  variables { name = "ab" }
  expect_failures = [var.name]
}

run "leading_dash_rejected" {
  command = plan
  variables { name = "-abc" }
  expect_failures = [var.name]
}

run "bad_storage_class_rejected" {
  command = plan
  variables { storage_class = "Cold" }
  expect_failures = [var.storage_class]
}

run "bad_versioning_rejected" {
  command = plan
  variables { versioning = "Off" }
  expect_failures = [var.versioning]
}

run "duplicate_rule_id_rejected" {
  command = plan
  variables {
    lifecycle_rules = [
      { id = "a", expiration_days = 1 },
      { id = "a", expiration_days = 2 },
    ]
  }
  expect_failures = [var.lifecycle_rules]
}

run "rule_without_action_rejected" {
  command = plan
  variables { lifecycle_rules = [{ id = "empty" }] }
  expect_failures = [var.lifecycle_rules]
}

run "zero_days_rejected" {
  command = plan
  variables { lifecycle_rules = [{ id = "a", expiration_days = 0 }] }
  expect_failures = [var.lifecycle_rules]
}

run "bad_transition_class_rejected" {
  command = plan
  variables { lifecycle_rules = [{ id = "a", transitions = [{ days = 30, storage_class = "Standard" }] }] }
  expect_failures = [var.lifecycle_rules]
}

run "kms_key_with_aes_rejected" {
  command = plan
  variables { kms_master_key_id = "key-abc" }
  expect_failures = [alicloud_oss_bucket.this]
}

run "empty_tags_rejected" {
  command = plan
  variables { tags = {} }
  expect_failures = [var.tags]
}

run "transition_not_before_expiration_rejected" {
  command = plan
  variables {
    lifecycle_rules = [{ id = "a", expiration_days = 30, transitions = [{ days = 30, storage_class = "IA" }] }]
  }
  expect_failures = [var.lifecycle_rules]
}
