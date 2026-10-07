mock_provider "alicloud" {}

variables {
  name          = "kafka-1-c1-example-stage"
  partition_num = 50
  disk_type     = "ssd"
  disk_size     = 500
  io_max_spec   = "alikafka.hw.2xlarge"
  placement     = [{ zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" }]
  allowed_ips   = ["10.0.0.0/16"]
  tags          = { env = "stage" }
}

run "single_zone_plain" {
  command = plan

  assert {
    condition     = alicloud_alikafka_instance.this.deploy_type == 5 && alicloud_alikafka_instance.this.paid_type == "PostPaid" && alicloud_alikafka_instance.this.disk_type == 1
    error_message = "VPC-only pay-as-you-go instance with an SSD disk"
  }

  assert {
    condition     = alicloud_alikafka_instance.this.selected_zones == null
    error_message = "single zone sets no selected_zones"
  }

  assert {
    condition     = length(alicloud_alikafka_instance_allowed_ip_attachment.this) == 1
    error_message = "without SASL users only the 9092 attachment exists"
  }
}

run "two_zones" {
  command = plan
  variables {
    placement = [
      { zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" },
      { zone_id = "ap-southeast-5b", vswitch_id = "vsw-b" },
    ]
  }

  assert {
    condition     = alicloud_alikafka_instance.this.selected_zones == tolist(["ap-southeast-5a", "ap-southeast-5b"]) && alicloud_alikafka_instance.this.zone_id == "ap-southeast-5a"
    error_message = "two placements must send both full zone IDs in order"
  }
}

run "same_zone_rejected" {
  command = plan
  variables {
    placement = [
      { zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" },
      { zone_id = "ap-southeast-5a", vswitch_id = "vsw-b" },
    ]
  }
  expect_failures = [var.placement]
}

run "three_zones_rejected" {
  command = plan
  variables {
    placement = [
      { zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" },
      { zone_id = "ap-southeast-5b", vswitch_id = "vsw-b" },
      { zone_id = "ap-southeast-5c", vswitch_id = "vsw-c" },
    ]
  }
  expect_failures = [var.placement]
}

run "topics_groups_remark_default" {
  command = plan
  variables {
    topics          = [{ name = "orders.v1" }, { name = "events", partition_num = 6, remark = "event-stream" }]
    consumer_groups = [{ name = "app" }]
  }

  assert {
    condition     = alicloud_alikafka_topic.this["orders.v1"].remark == "orders-v1" && alicloud_alikafka_topic.this["orders.v1"].partition_num == 12 && alicloud_alikafka_topic.this["events"].remark == "event-stream"
    error_message = "remark defaults to the name with '.' replaced and partitions default to 12"
  }

  assert {
    condition     = alicloud_alikafka_consumer_group.this["app"].remark == "app"
    error_message = "consumer group remark defaults to its name"
  }
}

run "sasl_users_and_acls" {
  command = apply
  variables {
    spec_type = "professional"
    topics    = [{ name = "orders" }]
    sasl_users = [{
      name = "app"
      acls = [
        { resource_type = "Topic", resource_name = "orders", operation = "Write" },
        { resource_type = "Topic", resource_name = "orders", operation = "Read" },
        { resource_type = "Group", resource_name = "app", operation = "Read" },
      ]
    }]
  }

  assert {
    condition     = length(alicloud_alikafka_instance_allowed_ip_attachment.this) == 2 && alicloud_alikafka_instance_allowed_ip_attachment.this["9094/9094/10.0.0.0/16"].port_range == "9094/9094"
    error_message = "SASL users add the 9094 attachment"
  }

  assert {
    condition     = alicloud_alikafka_instance.this.config == jsonencode({ "enable.acl" = "true" })
    error_message = "SASL users must enable the instance ACL"
  }

  assert {
    condition     = length(alicloud_alikafka_sasl_acl.this) == 3 && alicloud_alikafka_sasl_user.this["app"].type == "scram"
    error_message = "one ACL per entry, user type defaults to scram"
  }

  assert {
    condition     = length(random_password.sasl) == 1 && nonsensitive(length(output.generated_passwords["app"])) == 16
    error_message = "a user without a password must get a random 16 character one"
  }
}

run "supplied_sasl_password_not_generated" {
  command = apply
  variables {
    spec_type      = "professional"
    sasl_users     = [{ name = "app" }]
    sasl_passwords = { app = "Sup3rSecret1" }
  }

  assert {
    condition     = length(random_password.sasl) == 0 && nonsensitive(length(output.generated_passwords)) == 0
    error_message = "a supplied password must not be regenerated or output"
  }
}

run "sasl_on_normal_edition_rejected" {
  command = plan
  variables {
    sasl_users = [{ name = "app" }]
  }
  expect_failures = [var.spec_type]
}

run "password_for_unknown_user_rejected" {
  command = plan
  variables {
    spec_type      = "professional"
    sasl_users     = [{ name = "app" }]
    sasl_passwords = { ghost = "Sup3rSecret1" }
  }
  expect_failures = [var.sasl_passwords]
}

run "password_with_special_char_rejected" {
  command = plan
  variables {
    spec_type      = "professional"
    sasl_users     = [{ name = "app" }]
    sasl_passwords = { app = "Sup3r-Secret1" }
  }
  expect_failures = [var.sasl_passwords]
}

run "topic_double_underscore_rejected" {
  command = plan
  variables { topics = [{ name = "__x1" }] }
  expect_failures = [var.topics]
}

run "topic_short_name_rejected" {
  command = plan
  variables { topics = [{ name = "ab" }] }
  expect_failures = [var.topics]
}

run "duplicate_topic_rejected" {
  command = plan
  variables { topics = [{ name = "orders" }, { name = "orders" }] }
  expect_failures = [var.topics]
}

run "topic_partitions_zero_rejected" {
  command = plan
  variables { topics = [{ name = "orders", partition_num = 0 }] }
  expect_failures = [var.topics]
}

run "topic_partitions_361_rejected" {
  command = plan
  variables { topics = [{ name = "orders", partition_num = 361 }] }
  expect_failures = [var.topics]
}

run "cloud_topic_one_partition_rejected" {
  command = plan
  variables { topics = [{ name = "orders", partition_num = 1 }] }
  expect_failures = [var.topics]
}

run "compact_without_local_rejected" {
  command = plan
  variables {
    spec_type = "professional"
    topics    = [{ name = "orders", compact_topic = true }]
  }
  expect_failures = [var.topics]
}

run "local_topic_on_normal_rejected" {
  command = plan
  variables { topics = [{ name = "orders", local_topic = true }] }
  expect_failures = [var.topics]
}

run "local_compact_topic_professional_valid" {
  command = plan
  variables {
    spec_type = "professional"
    topics    = [{ name = "orders", partition_num = 1, local_topic = true, compact_topic = true }]
  }

  assert {
    condition     = alicloud_alikafka_topic.this["orders"].local_topic && alicloud_alikafka_topic.this["orders"].compact_topic
    error_message = "local compact topic must pass through"
  }
}

run "duplicate_group_rejected" {
  command = plan
  variables { consumer_groups = [{ name = "app" }, { name = "app" }] }
  expect_failures = [var.consumer_groups]
}

run "bad_acl_operation_rejected" {
  command = plan
  variables {
    spec_type  = "professional"
    sasl_users = [{ name = "app", acls = [{ resource_type = "Topic", resource_name = "orders", operation = "Delete" }] }]
  }
  expect_failures = [var.sasl_users]
}

run "bad_acl_pattern_rejected" {
  command = plan
  variables {
    spec_type  = "professional"
    sasl_users = [{ name = "app", acls = [{ resource_type = "Topic", resource_name = "orders", pattern = "REGEX", operation = "Read" }] }]
  }
  expect_failures = [var.sasl_users]
}

run "duplicate_acl_rejected" {
  command = plan
  variables {
    spec_type = "professional"
    sasl_users = [{ name = "app", acls = [
      { resource_type = "Topic", resource_name = "orders", operation = "Read" },
      { resource_type = "Topic", resource_name = "orders", operation = "Read" },
    ] }]
  }
  expect_failures = [var.sasl_users]
}

run "bad_user_type_rejected" {
  command = plan
  variables {
    spec_type  = "professional"
    sasl_users = [{ name = "app", type = "ldap" }]
  }
  expect_failures = [var.sasl_users]
}

run "long_name_rejected" {
  command = plan
  variables { name = "k123456789012345678901234567890123456789012345678901234567890123456" }
  expect_failures = [var.name]
}

run "open_internet_rejected" {
  command = plan
  variables { allowed_ips = ["0.0.0.0/0"] }
  expect_failures = [var.allowed_ips]
}

run "bare_ip_rejected" {
  command = plan
  variables { allowed_ips = ["10.0.0.5"] }
  expect_failures = [var.allowed_ips]
}

run "too_many_allowed_ips_rejected" {
  command = plan
  variables { allowed_ips = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24", "10.0.7.0/24", "10.0.8.0/24", "10.0.9.0/24", "10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24", "10.0.14.0/24", "10.0.15.0/24", "10.0.16.0/24", "10.0.17.0/24", "10.0.18.0/24", "10.0.19.0/24", "10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24", "10.0.24.0/24", "10.0.25.0/24", "10.0.26.0/24", "10.0.27.0/24", "10.0.28.0/24", "10.0.29.0/24", "10.0.30.0/24", "10.0.31.0/24", "10.0.32.0/24", "10.0.33.0/24", "10.0.34.0/24", "10.0.35.0/24", "10.0.36.0/24", "10.0.37.0/24", "10.0.38.0/24", "10.0.39.0/24", "10.0.40.0/24", "10.0.41.0/24", "10.0.42.0/24", "10.0.43.0/24", "10.0.44.0/24", "10.0.45.0/24", "10.0.46.0/24", "10.0.47.0/24", "10.0.48.0/24", "10.0.49.0/24", "10.0.50.0/24", "10.0.51.0/24", "10.0.52.0/24", "10.0.53.0/24", "10.0.54.0/24", "10.0.55.0/24", "10.0.56.0/24", "10.0.57.0/24", "10.0.58.0/24", "10.0.59.0/24", "10.0.60.0/24", "10.0.61.0/24", "10.0.62.0/24", "10.0.63.0/24", "10.0.64.0/24", "10.0.65.0/24", "10.0.66.0/24", "10.0.67.0/24", "10.0.68.0/24", "10.0.69.0/24", "10.0.70.0/24", "10.0.71.0/24", "10.0.72.0/24", "10.0.73.0/24", "10.0.74.0/24", "10.0.75.0/24", "10.0.76.0/24", "10.0.77.0/24", "10.0.78.0/24", "10.0.79.0/24", "10.0.80.0/24", "10.0.81.0/24", "10.0.82.0/24", "10.0.83.0/24", "10.0.84.0/24", "10.0.85.0/24", "10.0.86.0/24", "10.0.87.0/24", "10.0.88.0/24", "10.0.89.0/24", "10.0.90.0/24", "10.0.91.0/24", "10.0.92.0/24", "10.0.93.0/24", "10.0.94.0/24", "10.0.95.0/24", "10.0.96.0/24", "10.0.97.0/24", "10.0.98.0/24", "10.0.99.0/24", "10.0.100.0/24", "10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24", "10.0.104.0/24", "10.0.105.0/24", "10.0.106.0/24", "10.0.107.0/24", "10.0.108.0/24", "10.0.109.0/24", "10.0.110.0/24", "10.0.111.0/24", "10.0.112.0/24", "10.0.113.0/24", "10.0.114.0/24", "10.0.115.0/24", "10.0.116.0/24", "10.0.117.0/24", "10.0.118.0/24", "10.0.119.0/24", "10.0.120.0/24", "10.0.121.0/24", "10.0.122.0/24", "10.0.123.0/24", "10.0.124.0/24", "10.0.125.0/24", "10.0.126.0/24", "10.0.127.0/24", "10.0.128.0/24", "10.0.129.0/24", "10.0.130.0/24", "10.0.131.0/24", "10.0.132.0/24", "10.0.133.0/24", "10.0.134.0/24", "10.0.135.0/24", "10.0.136.0/24", "10.0.137.0/24", "10.0.138.0/24", "10.0.139.0/24", "10.0.140.0/24", "10.0.141.0/24", "10.0.142.0/24", "10.0.143.0/24", "10.0.144.0/24", "10.0.145.0/24", "10.0.146.0/24", "10.0.147.0/24", "10.0.148.0/24", "10.0.149.0/24", "10.0.150.0/24", "10.0.151.0/24", "10.0.152.0/24", "10.0.153.0/24", "10.0.154.0/24", "10.0.155.0/24", "10.0.156.0/24", "10.0.157.0/24", "10.0.158.0/24", "10.0.159.0/24", "10.0.160.0/24", "10.0.161.0/24", "10.0.162.0/24", "10.0.163.0/24", "10.0.164.0/24", "10.0.165.0/24", "10.0.166.0/24", "10.0.167.0/24", "10.0.168.0/24", "10.0.169.0/24", "10.0.170.0/24", "10.0.171.0/24", "10.0.172.0/24", "10.0.173.0/24", "10.0.174.0/24", "10.0.175.0/24", "10.0.176.0/24", "10.0.177.0/24", "10.0.178.0/24", "10.0.179.0/24", "10.0.180.0/24", "10.0.181.0/24", "10.0.182.0/24", "10.0.183.0/24", "10.0.184.0/24", "10.0.185.0/24", "10.0.186.0/24", "10.0.187.0/24", "10.0.188.0/24", "10.0.189.0/24", "10.0.190.0/24", "10.0.191.0/24", "10.0.192.0/24", "10.0.193.0/24", "10.0.194.0/24", "10.0.195.0/24", "10.0.196.0/24", "10.0.197.0/24", "10.0.198.0/24", "10.0.199.0/24", "10.0.200.0/24"] }
  expect_failures = [var.allowed_ips]
}

run "small_disk_rejected" {
  command = plan
  variables { disk_size = 100 }
  expect_failures = [var.disk_size]
}

run "disk_size_step_rejected" {
  command = plan
  variables { disk_size = 550 }
  expect_failures = [var.disk_size]
}

run "disk_size_over_max_rejected" {
  command = plan
  variables { disk_size = 6200 }
  expect_failures = [var.disk_size]
}

run "bad_disk_type_rejected" {
  command = plan
  variables { disk_type = "nvme" }
  expect_failures = [var.disk_type]
}

run "empty_tags_rejected" {
  command = plan
  variables { tags = {} }
  expect_failures = [var.tags]
}

run "password_length_honoured" {
  command = apply
  variables {
    spec_type       = "professional"
    sasl_users      = [{ name = "app" }]
    password_length = 24
  }

  assert {
    condition     = random_password.sasl["app"].length == 24
    error_message = "password_length must reach the generator"
  }
}
