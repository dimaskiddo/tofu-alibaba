mock_provider "alicloud" {}

variables {
  tags = { env = "stage" }
  instances = {
    mongodb-1-c1-example-stage = {
      architecture   = "replica_set"
      engine_version = "7.0"
      instance_class = "mdb.shard.2x.xlarge.d"
      storage_gb     = 20
      vpc_id         = "vpc-1"
      vswitch_id     = "vsw-a"
      zone_id        = "ap-southeast-5a"
      security_ips   = ["10.0.0.0/16"]
      tags           = { component = "mongodb" }
    }
    mongodb-2-c1-example-stage = {
      architecture   = "sharded"
      engine_version = "7.0"
      mongos         = [{ node_class = "m" }, { node_class = "m" }]
      shards         = [{ node_class = "s", node_storage = 20 }, { node_class = "s", node_storage = 20 }]
      vpc_id         = "vpc-1"
      vswitch_id     = "vsw-a"
      zone_id        = "ap-southeast-5a"
      security_ips   = ["10.0.0.0/16"]
    }
  }
  mongodb_passwords = {
    mongodb-1-c1-example-stage = "Sup3r-Secret1"
  }
}

run "keyed_by_name_and_tags_merged" {
  command = plan

  assert {
    condition     = contains(keys(output.instances), "mongodb-1-c1-example-stage") && output.instances["mongodb-1-c1-example-stage"].tags == tomap({ env = "stage", component = "mongodb" })
    error_message = "instance must be keyed by name with its tags merged over the shared tags"
  }

  assert {
    condition     = contains(keys(output.instances), "mongodb-2-c1-example-stage") && output.instances["mongodb-2-c1-example-stage"].tags == tomap({ env = "stage" })
    error_message = "a sharded instance must be created next to a replica set"
  }
}

run "supplied_password_routed_not_generated" {
  command = apply

  assert {
    condition     = nonsensitive(length(output.generated_passwords["mongodb-1-c1-example-stage"])) == 0 && nonsensitive(length(output.generated_passwords["mongodb-2-c1-example-stage"]["root"])) == 16
    error_message = "a supplied password must route to its instance; the other one is generated"
  }
}

run "missing_password_generated_and_hidden" {
  command = apply
  variables { mongodb_passwords = {} }

  assert {
    condition     = nonsensitive(length(output.generated_passwords["mongodb-1-c1-example-stage"]["root"])) == 16 && !contains(keys(output.instances["mongodb-1-c1-example-stage"]), "generated_passwords")
    error_message = "generated secret must appear only under generated_passwords"
  }
}

run "password_key_typo_rejected" {
  command = plan
  variables { mongodb_passwords = { mongodb-1-c1-exmaple-stage = "Sup3r-Secret1" } }
  expect_failures = [var.mongodb_passwords]
}

run "unknown_key_rejected" {
  command = plan
  variables {
    instances = {
      mongodb-1-c1-example-stage = {
        architecture   = "replica_set"
        engine_version = "7.0"
        instance_class = "mdb.shard.2x.xlarge.d"
        storage_gb     = 20
        vpc_id         = "vpc-1"
        vswitch_id     = "vsw-a"
        zone_id        = "ap-southeast-5a"
        security_ips   = ["10.0.0.0/16"]
        bogus          = true
      }
    }
  }
  expect_failures = [var.instances]
}

run "empty_instances_rejected" {
  command = plan
  variables { instances = {} }
  expect_failures = [var.instances]
}
