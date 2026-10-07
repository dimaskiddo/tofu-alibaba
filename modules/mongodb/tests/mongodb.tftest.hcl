mock_provider "alicloud" {}

variables {
  name           = "mongodb-1-c1-example-stage"
  architecture   = "replica_set"
  engine_version = "7.0"
  instance_class = "mdb.shard.2x.xlarge.d"
  storage_gb     = 20
  vpc_id         = "vpc-1"
  vswitch_id     = "vsw-a"
  zone_id        = "ap-southeast-5a"
  security_ips   = ["10.0.0.0/16"]
  tags           = { env = "stage" }
  password       = "Sup3r-Secret1"
}

run "replica_set_selected" {
  command = plan

  assert {
    condition     = length(alicloud_mongodb_instance.this) == 1 && length(alicloud_mongodb_sharding_instance.this) == 0
    error_message = "replica_set must create only the replica set instance"
  }

  assert {
    condition     = alicloud_mongodb_instance.this[0].instance_charge_type == "PostPaid" && alicloud_mongodb_instance.this[0].db_instance_release_protection == false
    error_message = "pay-as-you-go and release protection off by default"
  }

  assert {
    condition     = alicloud_mongodb_instance.this[0].tags == tomap({ env = "stage" }) && alicloud_mongodb_instance.this[0].security_ip_list == toset(["10.0.0.0/16"])
    error_message = "tags and security_ips must reach the instance"
  }
}

run "sharded_selected" {
  command = plan
  variables {
    architecture   = "sharded"
    instance_class = null
    storage_gb     = null
    mongos         = [{ node_class = "mdb.mongos.2x.xlarge.d" }, { node_class = "mdb.mongos.2x.xlarge.d" }]
    shards = [
      { node_class = "mdb.shard.2x.xlarge.d", node_storage = 20 },
      { node_class = "mdb.shard.2x.xlarge.d", node_storage = 20, readonly_replicas = 1 },
    ]
    config_server = { node_class = "mdb.config.2x.xlarge.d", node_storage = 20 }
  }

  assert {
    condition     = length(alicloud_mongodb_instance.this) == 0 && length(alicloud_mongodb_sharding_instance.this) == 1
    error_message = "sharded must create only the sharding instance"
  }

  assert {
    condition     = length(alicloud_mongodb_sharding_instance.this[0].mongo_list) == 2 && length(alicloud_mongodb_sharding_instance.this[0].shard_list) == 2 && length(alicloud_mongodb_sharding_instance.this[0].config_server_list) == 1
    error_message = "mongos, shard and config server lists must reach the instance"
  }
}

run "multi_zone_extras_passed" {
  command = plan
  variables {
    storage_type           = "cloud_essd1"
    secondary_zone_id      = "ap-southeast-5b"
    hidden_zone_id         = "ap-southeast-5c"
    replication_factor     = 3
    readonly_replicas      = 1
    disk_encryption_key_id = "key-1"
    backup                 = { period = ["Monday", "Thursday"], time = "02:00Z-03:00Z", retention_days = 14 }
    parameters             = { "operationProfiling.slowOpThresholdMs" = "200" }
  }

  assert {
    condition     = alicloud_mongodb_instance.this[0].secondary_zone_id == "ap-southeast-5b" && alicloud_mongodb_instance.this[0].hidden_zone_id == "ap-southeast-5c"
    error_message = "zones must reach the instance"
  }

  assert {
    condition     = alicloud_mongodb_instance.this[0].encrypted == true && alicloud_mongodb_instance.this[0].cloud_disk_encryption_key == "key-1"
    error_message = "disk encryption must reach the instance"
  }

  assert {
    condition     = alicloud_mongodb_instance.this[0].backup_time == "02:00Z-03:00Z" && alicloud_mongodb_instance.this[0].backup_retention_period == 14 && length(alicloud_mongodb_instance.this[0].parameters) == 1
    error_message = "backup policy and parameters must reach the instance"
  }
}

run "deletion_protection_can_be_on" {
  command = plan
  variables { deletion_protection = true }

  assert {
    condition     = alicloud_mongodb_instance.this[0].db_instance_release_protection == true
    error_message = "an explicit true must turn release protection on"
  }
}

run "password_generated_and_hidden_when_unset" {
  command = apply
  variables { password = null }

  assert {
    condition     = nonsensitive(length(output.generated_passwords["root"])) == 16
    error_message = "a missing password must be generated"
  }
}

run "endpoints_replica_set" {
  command = apply
  override_resource {
    target = alicloud_mongodb_instance.this
    values = {
      replica_sets     = [{ replica_set_role = "Primary", connection_domain = "dds-1.mongodb.rds.aliyuncs.com", connection_port = 3717, vpc_id = "vpc-1", vswitch_id = "vsw-a", network_type = "VPC", vpc_cloud_instance_id = "", role_id = "r1" }]
      replica_set_name = "mgset-1"
    }
  }

  assert {
    condition     = length(output.endpoints) == 1 && output.endpoints[0].role == "Primary" && output.endpoints[0].domain == "dds-1.mongodb.rds.aliyuncs.com" && output.endpoints[0].port == "3717" && output.replica_set_name == "mgset-1"
    error_message = "replica set endpoints must list role, domain and port"
  }
}

run "endpoints_sharded" {
  command = apply
  variables {
    architecture   = "sharded"
    instance_class = null
    storage_gb     = null
    mongos         = [{ node_class = "mdb.mongos.2x.xlarge.d" }, { node_class = "mdb.mongos.2x.xlarge.d" }]
    shards         = [{ node_class = "mdb.shard.2x.xlarge.d", node_storage = 20 }, { node_class = "mdb.shard.2x.xlarge.d", node_storage = 20 }]
  }
  assert {
    condition     = length(output.endpoints) == 2 && output.endpoints[0].role == "mongos" && output.replica_set_name == null
    error_message = "sharded endpoints must list the mongos routers"
  }
}

run "whole_internet_rejected" {
  command = plan
  variables { security_ips = ["0.0.0.0/0"] }
  expect_failures = [var.security_ips]
}

run "duplicate_ip_rejected" {
  command = plan
  variables { security_ips = ["10.0.0.0/16", "10.0.0.0/16"] }
  expect_failures = [var.security_ips]
}

run "bad_version_rejected" {
  command = plan
  variables { engine_version = "3.4" }
  expect_failures = [var.engine_version]
}

run "bad_architecture_rejected" {
  command = plan
  variables { architecture = "standalone" }
  expect_failures = [var.architecture]
}

run "replica_set_needs_class" {
  command = plan
  variables { instance_class = null }
  expect_failures = [var.instance_class]
}

run "replica_set_needs_storage_step" {
  command = plan
  variables { storage_gb = 25 }
  expect_failures = [var.storage_gb]
}

run "bad_replication_factor_rejected" {
  command = plan
  variables { replication_factor = 4 }
  expect_failures = [var.replication_factor]
}

run "too_many_readonly_replicas_rejected" {
  command = plan
  variables { readonly_replicas = 6 }
  expect_failures = [var.readonly_replicas]
}

run "sharded_rejects_replica_set_inputs" {
  command = plan
  variables {
    architecture = "sharded"
    mongos       = [{ node_class = "m" }, { node_class = "m" }]
    shards       = [{ node_class = "s", node_storage = 20 }, { node_class = "s", node_storage = 20 }]
  }
  expect_failures = [var.instance_class, var.storage_gb]
}

run "sharded_needs_two_mongos" {
  command = plan
  variables {
    architecture   = "sharded"
    instance_class = null
    storage_gb     = null
    mongos         = [{ node_class = "m" }]
    shards         = [{ node_class = "s", node_storage = 20 }, { node_class = "s", node_storage = 20 }]
  }
  expect_failures = [var.mongos]
}

run "sharded_needs_two_shards" {
  command = plan
  variables {
    architecture   = "sharded"
    instance_class = null
    storage_gb     = null
    mongos         = [{ node_class = "m" }, { node_class = "m" }]
    shards         = [{ node_class = "s", node_storage = 20 }]
  }
  expect_failures = [var.shards]
}

run "replica_set_rejects_shards" {
  command = plan
  variables { shards = [{ node_class = "s", node_storage = 20 }, { node_class = "s", node_storage = 20 }] }
  expect_failures = [var.shards]
}

run "replica_set_rejects_config_server" {
  command = plan
  variables { config_server = { node_class = "c", node_storage = 20 } }
  expect_failures = [var.config_server]
}

run "duplicate_zones_rejected" {
  command = plan
  variables {
    storage_type      = "cloud_essd1"
    secondary_zone_id = "ap-southeast-5a"
  }
  expect_failures = [var.secondary_zone_id]
}

run "hidden_zone_equal_secondary_rejected" {
  command = plan
  variables {
    storage_type      = "cloud_essd1"
    secondary_zone_id = "ap-southeast-5b"
    hidden_zone_id    = "ap-southeast-5b"
  }
  expect_failures = [var.hidden_zone_id]
}

run "secondary_zone_on_local_ssd_rejected" {
  command = plan
  variables {
    storage_type      = "local_ssd"
    secondary_zone_id = "ap-southeast-5b"
  }
  expect_failures = [var.storage_type]
}

run "encryption_on_old_default_local_disk_rejected" {
  command = plan
  variables {
    engine_version         = "4.2"
    disk_encryption_key_id = "key-1"
  }
  expect_failures = [var.storage_type]
}

run "bad_backup_window_rejected" {
  command = plan
  variables { backup = { period = ["Monday"], time = "01:00Z-03:00Z" } }
  expect_failures = [var.backup]
}

run "bad_backup_weekday_rejected" {
  command = plan
  variables { backup = { period = ["Mon"], time = "01:00Z-02:00Z" } }
  expect_failures = [var.backup]
}

run "empty_backup_period_rejected" {
  command = plan
  variables { backup = { period = [], time = "01:00Z-02:00Z" } }
  expect_failures = [var.backup]
}

run "bad_password_rejected" {
  command = plan
  variables { password = "short" }
  expect_failures = [var.password]
}

run "empty_parameter_value_rejected" {
  command = plan
  variables { parameters = { a = "" } }
  expect_failures = [var.parameters]
}

run "empty_tags_rejected" {
  command = plan
  variables { tags = {} }
  expect_failures = [var.tags]
}

run "invalid_name_rejected" {
  command = plan
  variables { name = "Mongo_1" }
  expect_failures = [var.name]
}
