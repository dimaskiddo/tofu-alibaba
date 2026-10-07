mock_provider "alicloud" {}

variables {
  tags = { env = "stage" }
  instances = {
    es-1-c1-example-stage = {
      es_version        = "7.10_with_X-Pack"
      vswitch_id        = "vsw-a"
      private_whitelist = ["10.0.0.0/16"]
      data_node         = { spec = "elasticsearch.sn2ne.large", amount = 2, disk = 20, performance_level = "PL1" }
      tags              = { component = "elasticsearch" }
    }
  }
  elasticsearch_passwords = {
    es-1-c1-example-stage = "Sup3r-Secret1"
  }
}

run "keyed_by_name_and_tags_merged" {
  command = plan

  assert {
    condition     = contains(keys(output.instances), "es-1-c1-example-stage") && output.instances["es-1-c1-example-stage"].tags == tomap({ env = "stage", component = "elasticsearch" })
    error_message = "instance must be keyed by name with its tags merged over the shared tags"
  }
}

run "supplied_password_routed_not_generated" {
  command = apply

  assert {
    condition     = nonsensitive(length(output.generated_passwords["es-1-c1-example-stage"])) == 0
    error_message = "a supplied password must route to its instance instead of being generated"
  }
}

run "missing_password_generated_and_hidden" {
  command = apply
  variables { elasticsearch_passwords = {} }

  assert {
    condition     = nonsensitive(length(output.generated_passwords["es-1-c1-example-stage"]["elastic"])) == 16 && !contains(keys(output.instances["es-1-c1-example-stage"]), "generated_passwords")
    error_message = "generated secret must appear only under generated_passwords"
  }
}

run "password_key_typo_rejected" {
  command = plan
  variables { elasticsearch_passwords = { es-1-c1-exmaple-stage = "Sup3r-Secret1" } }
  expect_failures = [var.elasticsearch_passwords]
}

run "unknown_key_rejected" {
  command = plan
  variables {
    instances = {
      es-1-c1-example-stage = {
        es_version        = "7.10_with_X-Pack"
        vswitch_id        = "vsw-a"
        private_whitelist = ["10.0.0.0/16"]
        data_node         = { spec = "elasticsearch.sn2ne.large", amount = 2, disk = 20, performance_level = "PL1" }
        enable_public     = true
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
    instances = { es-1-c1-example-stage = {
      es_version = "7.10_with_X-Pack", vswitch_id = "vsw-a", private_whitelist = ["10.0.0.0/16"]
      data_node  = { spec = "elasticsearch.sn2ne.large", amount = 2, disk = 20, performance_lvl = "PL1" }
    } }
  }
  expect_failures = [var.instances]
}
