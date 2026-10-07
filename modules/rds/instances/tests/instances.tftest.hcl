mock_provider "alicloud" {}

variables {
  tags = { env = "stage" }
  instances = {
    main-1-c1-example-stage = {
      engine           = "MySQL"
      engine_version   = "8.0"
      category         = "Basic"
      instance_type    = "mysql.n2.medium.1"
      instance_storage = 20
      placement        = [{ zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" }]
      security_ips     = ["10.0.0.0/16"]
      accounts         = [{ name = "app" }]
      tags             = { component = "rds" }
    }
  }
  account_passwords = {
    main-1-c1-example-stage = { app = "Sup3r-Secret1" }
  }
}

run "keyed_by_name_and_tags_merged" {
  command = plan

  assert {
    condition     = contains(keys(output.instances), "main-1-c1-example-stage") && output.instances["main-1-c1-example-stage"].tags == tomap({ env = "stage", component = "rds" })
    error_message = "instance must be keyed by name with its tags merged over the shared tags"
  }
}

run "supplied_password_routed_not_generated" {
  command = apply

  assert {
    condition     = nonsensitive(length(output.generated_passwords["main-1-c1-example-stage"])) == 0
    error_message = "a supplied password must route to its instance and account instead of being generated"
  }
}

run "password_key_typo_rejected" {
  command = plan
  variables {
    account_passwords = {
      main-1-c1-exmaple-stage = { app = "Sup3r-Secret1" }
    }
  }
  expect_failures = [var.account_passwords]
}

run "unknown_key_rejected" {
  command = plan
  variables {
    instances = {
      main-1-c1-example-stage = {
        engine           = "MySQL"
        engine_version   = "8.0"
        category         = "Basic"
        instance_type    = "mysql.n2.medium.1"
        instance_storage = 20
        placement        = [{ zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" }]
        security_ips     = ["10.0.0.0/16"]
        storage          = 40
      }
    }
  }
  expect_failures = [var.instances]
}

run "missing_password_generated" {
  command = apply
  variables { account_passwords = {} }

  assert {
    condition     = nonsensitive(length(output.generated_passwords["main-1-c1-example-stage"]["app"])) == 8
    error_message = "a missing password must be generated at the default length per instance and account"
  }

  assert {
    condition     = !contains(keys(output.instances["main-1-c1-example-stage"]), "generated_passwords")
    error_message = "the instances output must not carry generated passwords"
  }
}

run "password_length_per_instance" {
  command = apply
  variables {
    account_passwords = {}
    instances = {
      main-1-c1-example-stage = {
        engine           = "MySQL"
        engine_version   = "8.0"
        category         = "Basic"
        instance_type    = "mysql.n2.medium.1"
        instance_storage = 20
        placement        = [{ zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" }]
        security_ips     = ["10.0.0.0/16"]
        accounts         = [{ name = "app" }]
        password_length  = 14
      }
    }
  }

  assert {
    condition     = nonsensitive(length(output.generated_passwords["main-1-c1-example-stage"]["app"])) == 14
    error_message = "password_length must route per instance"
  }
}

run "empty_instances_rejected" {
  command = plan
  variables { instances = {} }
  expect_failures = [var.instances]
}

run "nested_unknown_key_rejected" {
  command = plan
  variables {
    instances = { main-1-c1-example-stage = {
      engine    = "MySQL", engine_version = "8.0", category = "Basic", instance_type = "mysql.n2.medium.1", instance_storage = 20
      placement = [{ zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" }], security_ips = ["10.0.0.0/16"]
      backup    = { backup_retention_perod = 7 }
    } }
  }
  expect_failures = [var.instances]
}

run "null_optionals_accepted" {
  command = plan
  variables {
    instances = {
      main-1-c1-example-stage = {
        engine             = "MySQL"
        engine_version     = "8.0"
        category           = "Basic"
        instance_type      = "mysql.n2.medium.1"
        instance_storage   = 20
        placement          = [{ zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" }]
        security_ips       = ["10.0.0.0/16"]
        accounts           = [{ name = "app" }]
        parameters         = null
        backup             = null
        storage_auto_scale = null
        databases          = null
      }
    }
  }

  assert {
    condition     = contains(keys(output.instances), "main-1-c1-example-stage")
    error_message = "leaves pass omitted optional keys as null; the wrapper checks must accept them"
  }
}
