mock_provider "alicloud" {}

variables {
  tags = { env = "stage" }
  instances = {
    kafka-1-c1-example-stage = {
      partition_num = 50
      disk_type     = "ssd"
      disk_size     = 500
      io_max_spec   = "alikafka.hw.2xlarge"
      spec_type     = "professional"
      placement     = [{ zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" }]
      allowed_ips   = ["10.0.0.0/16"]
      sasl_users    = [{ name = "app" }]
      tags          = { component = "kafka" }
    }
  }
  kafka_sasl_passwords = {
    kafka-1-c1-example-stage = { app = "Sup3rSecret1" }
  }
}

run "keyed_by_name_and_tags_merged" {
  command = plan

  assert {
    condition     = contains(keys(output.instances), "kafka-1-c1-example-stage") && output.instances["kafka-1-c1-example-stage"].tags == tomap({ env = "stage", component = "kafka" })
    error_message = "instance must be keyed by name with its tags merged over the shared tags"
  }
}

run "supplied_password_routed_not_generated" {
  command = apply

  assert {
    condition     = nonsensitive(length(output.generated_passwords["kafka-1-c1-example-stage"])) == 0
    error_message = "a supplied password must route to its instance and user instead of being generated"
  }
}

run "missing_password_generated_and_hidden" {
  command = apply
  variables { kafka_sasl_passwords = {} }

  assert {
    condition     = nonsensitive(length(output.generated_passwords["kafka-1-c1-example-stage"]["app"])) == 16 && !contains(keys(output.instances["kafka-1-c1-example-stage"]), "generated_passwords")
    error_message = "generated secret must appear only under generated_passwords"
  }
}

run "password_key_typo_rejected" {
  command = plan
  variables {
    kafka_sasl_passwords = { kafka-1-c1-exmaple-stage = { app = "Sup3rSecret1" } }
  }
  expect_failures = [var.kafka_sasl_passwords]
}

run "unknown_key_rejected" {
  command = plan
  variables {
    instances = {
      kafka-1-c1-example-stage = {
        partition_num = 50
        disk_type     = "ssd"
        disk_size     = 500
        io_max_spec   = "alikafka.hw.2xlarge"
        placement     = [{ zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" }]
        allowed_ips   = ["10.0.0.0/16"]
        eip_max       = 5
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

run "nested_unknown_key_rejected" {
  command = plan
  variables {
    instances = { kafka-1-c1-example-stage = {
      partition_num = 50, disk_type = "ssd", disk_size = 500, io_max_spec = "alikafka.hw.2xlarge", spec_type = "professional"
      placement     = [{ zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" }], allowed_ips = ["10.0.0.0/16"]
      topics        = [{ name = "orders", partition_nm = 3 }]
    } }
  }
  expect_failures = [var.instances]
}

run "null_optionals_accepted" {
  command = plan
  variables {
    instances = {
      kafka-1-c1-example-stage = {
        partition_num   = 50
        disk_type       = "ssd"
        disk_size       = 500
        io_max_spec     = "alikafka.hw.2xlarge"
        spec_type       = "professional"
        placement       = [{ zone_id = "ap-southeast-5a", vswitch_id = "vsw-a" }]
        allowed_ips     = ["10.0.0.0/16"]
        topics          = null
        consumer_groups = null
        sasl_users      = null
      }
    }
    kafka_sasl_passwords = {}
  }

  assert {
    condition     = contains(keys(output.instances), "kafka-1-c1-example-stage")
    error_message = "leaves pass omitted optional keys as null; the wrapper checks must accept them"
  }
}
