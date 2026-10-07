mock_provider "alicloud" {}

variables {
  name           = "redis-1-c1-example-stage"
  instance_type  = "Redis"
  engine_version = "7.0"
  instance_class = "redis.master.small.default"
  vpc_id         = "vpc-1"
  vswitch_id     = "vsw-a"
  zone_id        = "ap-southeast-5a"
  security_ips   = ["10.0.0.0/16"]
  tags           = { env = "stage" }
  password       = "Sup3r-Secret1"
}

run "redis_oss_selected" {
  command = plan

  assert {
    condition     = length(alicloud_kvstore_instance.this) == 1 && length(alicloud_redis_tair_instance.this) == 0
    error_message = "Redis must create only the kvstore instance"
  }

  assert {
    condition     = alicloud_kvstore_instance.this[0].payment_type == "PostPaid" && alicloud_kvstore_instance.this[0].instance_release_protection == false
    error_message = "pay-as-you-go and release protection off by default"
  }
}

run "tair_selected" {
  command = plan
  variables {
    instance_type  = "tair_rdb"
    instance_class = "tair.rdb.2g"
  }

  assert {
    condition     = length(alicloud_kvstore_instance.this) == 0 && length(alicloud_redis_tair_instance.this) == 1
    error_message = "Tair must create only the tair instance"
  }

  assert {
    condition     = alicloud_redis_tair_instance.this[0].payment_type == "PayAsYouGo" && alicloud_redis_tair_instance.this[0].security_ips == "10.0.0.0/16"
    error_message = "pay-as-you-go and comma-joined security_ips"
  }
}

run "secondary_zone_accepted" {
  command = plan
  variables { secondary_zone_id = "ap-southeast-5b" }

  assert {
    condition     = alicloud_kvstore_instance.this[0].secondary_zone_id == "ap-southeast-5b"
    error_message = "secondary zone must reach the instance"
  }
}

run "same_secondary_zone_rejected" {
  command = plan
  variables { secondary_zone_id = "ap-southeast-5a" }
  expect_failures = [var.secondary_zone_id]
}

run "redis_version_rejected" {
  command = plan
  variables { engine_version = "1.0" }
  expect_failures = [var.engine_version]
}

run "tair_scm_version_rejected" {
  command = plan
  variables {
    instance_type  = "tair_scm"
    engine_version = "7.0"
  }
  expect_failures = [var.engine_version]
}

run "tair_deletion_protection_rejected" {
  command = plan
  variables {
    instance_type       = "tair_rdb"
    deletion_protection = true
  }
  expect_failures = [var.deletion_protection]
}

run "open_internet_rejected" {
  command = plan
  variables { security_ips = ["0.0.0.0/0"] }
  expect_failures = [var.security_ips]
}

run "bad_ip_rejected" {
  command = plan
  variables { security_ips = ["10.0.0.0/33"] }
  expect_failures = [var.security_ips]
}

run "empty_tags_rejected" {
  command = plan
  variables { tags = {} }
  expect_failures = [var.tags]
}

run "bad_name_rejected" {
  command = plan
  variables { name = "Redis_1" }
  expect_failures = [var.name]
}

run "bad_vswitch_rejected" {
  command = plan
  variables { vswitch_id = "x" }
  expect_failures = [var.vswitch_id]
}

run "weak_password_rejected" {
  command = plan
  variables { password = "short" }
  expect_failures = [var.password]
}

run "missing_password_generated" {
  command = apply
  variables { password = null }

  assert {
    condition     = length(random_password.this) == 1 && nonsensitive(length(output.generated_passwords["default"])) == 16
    error_message = "a missing password must get a random 16 character one"
  }
}

run "supplied_password_not_generated" {
  command = apply

  assert {
    condition     = length(random_password.this) == 0 && nonsensitive(length(output.generated_passwords)) == 0
    error_message = "a supplied password must not be regenerated or output"
  }
}

run "password_length_honoured" {
  command = apply
  variables {
    password        = null
    password_length = 24
  }

  assert {
    condition     = random_password.this[0].length == 24
    error_message = "password_length must reach the generator"
  }
}

run "password_length_out_of_range_rejected" {
  command = plan
  variables { password_length = 7 }
  expect_failures = [var.password_length]
}

run "tair_essd_1_needs_storage" {
  command = plan
  variables {
    instance_type  = "tair_essd"
    engine_version = "1.0"
    instance_class = "tair.essd.standard.4c"
  }
  expect_failures = [var.storage_size_gb]
}

run "tair_essd_1_storage_passed" {
  command = plan
  variables {
    instance_type             = "tair_essd"
    engine_version            = "1.0"
    instance_class            = "tair.essd.standard.4c"
    storage_size_gb           = 100
    storage_performance_level = "PL1"
  }

  assert {
    condition     = alicloud_redis_tair_instance.this[0].storage_size_gb == 100 && alicloud_redis_tair_instance.this[0].storage_performance_level == "PL1"
    error_message = "ESSD storage fields must reach the Tair resource"
  }
}

run "storage_on_redis_rejected" {
  command = plan
  variables { storage_size_gb = 100 }
  expect_failures = [var.storage_size_gb]
}

run "tair_shard_count_over_32_rejected" {
  command = plan
  variables {
    instance_type  = "tair_rdb"
    instance_class = "tair.rdb.2g"
    shard_count    = 64
  }
  expect_failures = [var.shard_count]
}

run "redis_shard_count_64_valid" {
  command = plan
  variables { shard_count = 64 }

  assert {
    condition     = alicloud_kvstore_instance.this[0].shard_count == 64
    error_message = "Redis OSS accepts up to 256 shards"
  }
}

run "tair_needs_vpc_id" {
  command = plan
  variables {
    instance_type  = "tair_rdb"
    instance_class = "tair.rdb.2g"
    vpc_id         = null
  }
  expect_failures = [var.vpc_id]
}

run "redis_without_vpc_id_valid" {
  command = plan
  variables { vpc_id = null }

  assert {
    condition     = length(alicloud_kvstore_instance.this) == 1
    error_message = "Redis OSS needs no vpc_id"
  }
}

run "name_81_chars_rejected" {
  command = plan
  variables { name = "a123456789012345678901234567890123456789012345678901234567890123456789012345678901" }
  expect_failures = [var.name]
}
