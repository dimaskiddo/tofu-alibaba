mock_provider "alicloud" {}

variables {
  tags = { env = "stage" }
  instances = {
    redis-1-c1-example-stage = {
      instance_type  = "Redis"
      engine_version = "7.0"
      instance_class = "redis.master.small.default"
      vpc_id         = "vpc-1"
      vswitch_id     = "vsw-a"
      zone_id        = "ap-southeast-5a"
      security_ips   = ["10.0.0.0/16"]
      tags           = { component = "redis" }
    }
  }
  redis_passwords = {
    redis-1-c1-example-stage = "Sup3r-Secret1"
  }
}

run "keyed_by_name_and_tags_merged" {
  command = plan

  assert {
    condition     = contains(keys(output.instances), "redis-1-c1-example-stage") && output.instances["redis-1-c1-example-stage"].tags == tomap({ env = "stage", component = "redis" })
    error_message = "instance must be keyed by name with its tags merged over the shared tags"
  }
}

run "supplied_password_routed_not_generated" {
  command = apply

  assert {
    condition     = nonsensitive(length(output.generated_passwords["redis-1-c1-example-stage"])) == 0
    error_message = "a supplied password must route to its instance instead of being generated"
  }
}

run "missing_password_generated_and_hidden" {
  command = apply
  variables { redis_passwords = {} }

  assert {
    condition     = nonsensitive(length(output.generated_passwords["redis-1-c1-example-stage"]["default"])) == 16 && !contains(keys(output.instances["redis-1-c1-example-stage"]), "generated_passwords")
    error_message = "generated secret must appear only under generated_passwords"
  }
}

run "password_key_typo_rejected" {
  command = plan
  variables { redis_passwords = { redis-1-c1-exmaple-stage = "Sup3r-Secret1" } }
  expect_failures = [var.redis_passwords]
}

run "unknown_key_rejected" {
  command = plan
  variables {
    instances = {
      redis-1-c1-example-stage = {
        instance_type  = "Redis"
        engine_version = "7.0"
        instance_class = "redis.master.small.default"
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
