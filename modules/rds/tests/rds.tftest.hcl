mock_provider "alicloud" {}

variables {
  name             = "main-1-c1-example-stage"
  engine           = "MySQL"
  engine_version   = "8.0"
  category         = "Basic"
  instance_type    = "mysql.n2.medium.1"
  instance_storage = 20
  placement        = [{ zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" }]
  security_ips     = ["10.0.0.0/16"]
  tags             = { env = "stage" }
  databases        = [{ name = "app", character_set = "utf8mb4" }]
  accounts         = [{ name = "app", privilege = "ReadWrite", databases = ["app"] }]
  account_passwords = {
    app = "Sup3r-Secret1"
  }
}

run "basic_mysql" {
  command = plan

  assert {
    condition     = alicloud_db_instance.this.vswitch_id == "vsw-a" && alicloud_db_instance.this.zone_id == "ap-southeast-5a"
    error_message = "Basic uses one zone and one vSwitch"
  }

  assert {
    condition     = alicloud_db_backup_policy.this.enable_backup_log == false && alicloud_db_instance.this.deletion_protection == true
    error_message = "Basic has no log backup; deletion protection defaults on"
  }

  assert {
    condition     = alicloud_db_instance.this.storage_auto_scale == "Disable"
    error_message = "a null storage_auto_scale must send Disable"
  }

  assert {
    condition     = length(alicloud_db_database.this) == 1 && length(alicloud_rds_account.this) == 1 && alicloud_db_account_privilege.this["app"].privilege == "ReadWrite"
    error_message = "database, account and privilege must be created"
  }
}

run "ha_postgres_multi_zone_encrypted" {
  command = plan
  variables {
    engine         = "PostgreSQL"
    engine_version = "15.0"
    category       = "HighAvailability"
    instance_type  = "pg.n2.medium.2c"
    placement = [
      { zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" },
      { zone_id = "ap-southeast-5b", vswitch_id = "vsw-b" },
    ]
    databases          = [{ name = "app", character_set = "UTF8,C,en_US.utf8" }]
    accounts           = [{ name = "app", privilege = "DBOwner", databases = ["app"] }]
    encryption_key     = "key-123"
    storage_auto_scale = { threshold = 20, upper_bound = 100 }
    maintain_time      = "18:00Z-19:00Z"
  }

  assert {
    condition     = alicloud_db_instance.this.storage_auto_scale == "Enable" && alicloud_db_instance.this.zone_id_slave_a == "ap-southeast-5b" && alicloud_db_instance.this.vswitch_id == "vsw-a,vsw-b"
    error_message = "HA multi-zone sets the standby zone and comma-joined vSwitches"
  }

  assert {
    condition     = alicloud_db_backup_policy.this.enable_backup_log == true
    error_message = "HighAvailability enables log backup"
  }

  assert {
    condition     = alicloud_db_instance.this.encryption_key == "key-123" && strcontains(alicloud_db_instance.this.role_arn, ":role/aliyunrdsinstanceencryptiondefaultrole")
    error_message = "encryption key is passed and the default role ARN is derived"
  }

  assert {
    condition     = alicloud_db_instance.this.storage_auto_scale == "Enable" && alicloud_db_instance.this.storage_upper_bound == 100
    error_message = "storage auto-scale must be passed"
  }
}

run "explicit_role_arn" {
  command = plan
  variables {
    encryption_key = "key-123"
    role_arn       = "acs:ram::1:role/custom"
  }

  assert {
    condition     = alicloud_db_instance.this.role_arn == "acs:ram::1:role/custom"
    error_message = "explicit role_arn wins"
  }
}

run "mariadb_without_key" {
  command = plan
  variables {
    engine         = "MariaDB"
    engine_version = "10.3"
  }

  assert {
    condition     = alicloud_db_instance.this.engine == "MariaDB"
    error_message = "MariaDB is accepted without a key"
  }
}

run "mariadb_with_key_rejected" {
  command = plan
  variables {
    engine         = "MariaDB"
    engine_version = "10.3"
    encryption_key = "key-123"
  }
  expect_failures = [var.encryption_key]
}

run "sqlserver_rejected" {
  command = plan
  variables { engine = "SQLServer" }
  expect_failures = [var.engine]
}

run "basic_with_two_placements_rejected" {
  command = plan
  variables {
    placement = [
      { zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" },
      { zone_id = "ap-southeast-5b", vswitch_id = "vsw-b" },
    ]
  }
  expect_failures = [var.placement]
}

run "same_zone_twice_rejected" {
  command = plan
  variables {
    category = "HighAvailability"
    placement = [
      { zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" },
      { zone_id = "ap-southeast-5a", vswitch_id = "vsw-b" },
    ]
  }
  expect_failures = [var.placement]
}

run "bad_storage_rejected" {
  command = plan
  variables { instance_storage = 22 }
  expect_failures = [var.instance_storage]
}

run "essd_pl1_below_20_rejected" {
  command = plan
  variables { instance_storage = 15 }
  expect_failures = [var.instance_storage]
}

run "essd_pl2_below_500_rejected" {
  command = plan
  variables {
    db_instance_storage_type = "cloud_essd2"
    instance_storage         = 100
  }
  expect_failures = [var.instance_storage]
}

run "open_to_world_rejected" {
  command = plan
  variables { security_ips = ["0.0.0.0/0"] }
  expect_failures = [var.security_ips]
}

run "ipv6_rejected" {
  command = plan
  variables { security_ips = ["2001:db8::/32"] }
  expect_failures = [var.security_ips]
}

run "log_retention_above_retention_rejected" {
  command = plan
  variables {
    backup = { backup_retention_period = 7, log_backup_retention_period = 14 }
  }
  expect_failures = [var.backup]
}

run "backup_window_not_one_hour_rejected" {
  command = plan
  variables {
    backup = { preferred_backup_time = "02:00Z-05:00Z" }
  }
  expect_failures = [var.backup]
}

run "backup_window_last_hour_valid" {
  command = plan
  variables {
    backup = { preferred_backup_time = "23:00Z-24:00Z" }
  }

  assert {
    condition     = alicloud_db_backup_policy.this.preferred_backup_time == "23:00Z-24:00Z"
    error_message = "the 23:00Z-24:00Z window must be accepted"
  }
}

run "one_backup_day_rejected" {
  command = plan
  variables {
    backup = { preferred_backup_period = ["Monday"] }
  }
  expect_failures = [var.backup]
}

run "dbowner_on_mysql_rejected" {
  command = plan
  variables {
    accounts = [{ name = "app", privilege = "DBOwner", databases = ["app"] }]
  }
  expect_failures = [var.accounts]
}

run "two_super_on_mysql_rejected" {
  command = plan
  variables {
    accounts = [{ name = "root1", type = "Super" }, { name = "root2", type = "Super" }]
  }
  expect_failures = [var.accounts]
}

run "super_with_grant_rejected" {
  command = plan
  variables {
    accounts = [{ name = "root1", type = "Super", privilege = "ReadWrite", databases = ["app"] }]
  }
  expect_failures = [var.accounts]
}

run "super_alone_valid" {
  command = plan
  variables {
    accounts          = [{ name = "root1", type = "Super" }]
    account_passwords = {}
  }

  assert {
    condition     = length(alicloud_db_account_privilege.this) == 0
    error_message = "a Super account must not be granted"
  }
}

run "two_super_on_postgres_valid" {
  command = plan
  variables {
    engine            = "PostgreSQL"
    engine_version    = "15.0"
    instance_type     = "pg.n2.medium.2c"
    accounts          = [{ name = "root1", type = "Super" }, { name = "root2", type = "Super" }]
    account_passwords = {}
  }

  assert {
    condition     = length(alicloud_rds_account.this) == 2
    error_message = "PostgreSQL keeps multiple Super accounts"
  }
}

run "unknown_database_rejected" {
  command = plan
  variables {
    accounts = [{ name = "app", privilege = "ReadWrite", databases = ["missing"] }]
  }
  expect_failures = [var.accounts]
}

run "grant_without_privilege_rejected" {
  command = plan
  variables {
    accounts = [{ name = "app", databases = ["app"] }]
  }
  expect_failures = [var.accounts]
}

run "uppercase_account_rejected" {
  command = plan
  variables {
    accounts          = [{ name = "App" }]
    account_passwords = { App = "Sup3r-Secret1" }
  }
  expect_failures = [var.accounts]
}

run "missing_password_generated" {
  command = apply
  variables { account_passwords = {} }

  assert {
    condition     = length(random_password.account) == 1 && random_password.account["app"].length == 8 && nonsensitive(length(output.generated_passwords["app"])) == 8
    error_message = "an account without a password must get a random 8 character one"
  }
}

run "supplied_password_not_generated" {
  command = apply

  assert {
    condition     = length(random_password.account) == 0 && nonsensitive(length(output.generated_passwords)) == 0
    error_message = "a supplied password must not be regenerated or output"
  }
}

run "password_length_honoured" {
  command = apply
  variables {
    account_passwords = {}
    password_length   = 16
  }

  assert {
    condition     = random_password.account["app"].length == 16
    error_message = "password_length must reach the generator"
  }
}

run "password_length_out_of_range_rejected" {
  command = plan
  variables { password_length = 7 }
  expect_failures = [var.password_length]
}

run "password_for_unknown_account_rejected" {
  command = plan
  variables { account_passwords = { app = "Sup3r-Secret1", ghost = "Sup3r-Secret1" } }
  expect_failures = [var.account_passwords]
}

run "weak_password_rejected" {
  command = plan
  variables { account_passwords = { app = "alllowercase" } }
  expect_failures = [var.account_passwords]
}

run "empty_tags_rejected" {
  command = plan
  variables { tags = {} }
  expect_failures = [var.tags]
}
