mock_provider "alicloud" {}

variables {
  name              = "es-1-c1-example-stage"
  es_version        = "7.10_with_X-Pack"
  vswitch_id        = "vsw-a"
  private_whitelist = ["10.0.0.0/16"]
  tags              = { env = "stage" }
  password          = "Sup3r-Secret1"
  data_node = {
    spec              = "elasticsearch.sn2ne.large"
    amount            = 2
    disk              = 20
    performance_level = "PL1"
  }
}

run "single_zone_defaults" {
  command = plan

  assert {
    condition     = alicloud_elasticsearch_instance.this.zone_count == 1 && alicloud_elasticsearch_instance.this.payment_type == "PayAsYouGo" && alicloud_elasticsearch_instance.this.description == "es-1-c1-example-stage"
    error_message = "single zone, pay-as-you-go, name sent as description"
  }

  assert {
    condition     = alicloud_elasticsearch_instance.this.enable_public == false && alicloud_elasticsearch_instance.this.enable_kibana_public_network == false
    error_message = "public access must stay off"
  }

  assert {
    condition     = length(alicloud_elasticsearch_instance.this.master_configuration) == 0 && length(alicloud_elasticsearch_instance.this.kibana_configuration) == 0
    error_message = "no master or kibana block unless requested"
  }

  assert {
    condition     = alicloud_elasticsearch_instance.this.data_node_configuration[0].disk_type == "cloud_essd"
    error_message = "data disk defaults to cloud_essd"
  }
}

run "multi_zone_with_masters_and_kibana" {
  command = plan
  variables {
    zone_count       = 2
    master_node_spec = "elasticsearch.sn2ne.large"
    kibana_node_spec = "elasticsearch.n4.small"
  }

  assert {
    condition     = alicloud_elasticsearch_instance.this.master_configuration[0].amount == 3 && alicloud_elasticsearch_instance.this.master_configuration[0].disk == 20 && alicloud_elasticsearch_instance.this.kibana_configuration[0].amount == 1
    error_message = "3 masters of 20 GB and one Kibana node"
  }
}

run "multi_zone_without_master_rejected" {
  command = plan
  variables { zone_count = 2 }
  expect_failures = [var.zone_count]
}

run "amount_not_multiple_of_zones_rejected" {
  command = plan
  variables {
    zone_count       = 2
    master_node_spec = "elasticsearch.sn2ne.large"
    data_node = {
      spec              = "elasticsearch.sn2ne.large"
      amount            = 3
      disk              = 20
      performance_level = "PL1"
    }
  }
  expect_failures = [var.data_node]
}

run "amount_one_rejected" {
  command = plan
  variables {
    data_node = {
      spec              = "elasticsearch.sn2ne.large"
      amount            = 1
      disk              = 20
      performance_level = "PL1"
    }
  }
  expect_failures = [var.data_node]
}

run "amount_51_rejected" {
  command = plan
  variables {
    data_node = {
      spec              = "elasticsearch.sn2ne.large"
      amount            = 51
      disk              = 20
      performance_level = "PL1"
    }
  }
  expect_failures = [var.data_node]
}

run "essd_without_level_rejected" {
  command = plan
  variables {
    data_node = {
      spec   = "elasticsearch.sn2ne.large"
      amount = 2
      disk   = 20
    }
  }
  expect_failures = [var.data_node]
}

run "level_on_ssd_rejected" {
  command = plan
  variables {
    data_node = {
      spec              = "elasticsearch.sn2ne.large"
      amount            = 2
      disk              = 20
      disk_type         = "cloud_ssd"
      performance_level = "PL1"
    }
  }
  expect_failures = [var.data_node]
}

run "zone_count_four_rejected" {
  command = plan
  variables { zone_count = 4 }
  expect_failures = [var.zone_count]
}

run "bad_version_rejected" {
  command = plan
  variables { es_version = "7.10" }
  expect_failures = [var.es_version]
}

run "bad_protocol_rejected" {
  command = plan
  variables { protocol = "FTP" }
  expect_failures = [var.protocol]
}

run "open_internet_rejected" {
  command = plan
  variables { private_whitelist = ["0.0.0.0/0"] }
  expect_failures = [var.private_whitelist]
}

run "bad_vswitch_rejected" {
  command = plan
  variables { vswitch_id = "x" }
  expect_failures = [var.vswitch_id]
}

run "bad_name_rejected" {
  command = plan
  variables { name = "ES_1" }
  expect_failures = [var.name]
}

run "empty_tags_rejected" {
  command = plan
  variables { tags = {} }
  expect_failures = [var.tags]
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
    condition     = length(random_password.this) == 1 && nonsensitive(length(output.generated_passwords["elastic"])) == 16
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

run "kibana_private_network_follows_node" {
  command = plan

  assert {
    condition     = alicloud_elasticsearch_instance.this.enable_kibana_private_network == false
    error_message = "no Kibana node, no private Kibana network"
  }
}

run "kibana_node_enables_private_network" {
  command = plan
  variables { kibana_node_spec = "elasticsearch.n4.small" }

  assert {
    condition     = alicloud_elasticsearch_instance.this.enable_kibana_private_network == true && alicloud_elasticsearch_instance.this.enable_kibana_public_network == false
    error_message = "a Kibana node enables private access only"
  }
}

run "master_disk_is_cloud_ssd" {
  command = plan
  variables {
    zone_count       = 2
    master_node_spec = "elasticsearch.sn2ne.large"
  }

  assert {
    condition     = one(alicloud_elasticsearch_instance.this.master_configuration).disk_type == "cloud_ssd"
    error_message = "masters only accept cloud_ssd"
  }
}

run "empty_master_spec_rejected" {
  command = plan
  variables { master_node_spec = "" }
  expect_failures = [var.master_node_spec]
}

run "empty_kibana_spec_rejected" {
  command = plan
  variables { kibana_node_spec = " " }
  expect_failures = [var.kibana_node_spec]
}

run "too_many_whitelist_rejected" {
  command = plan
  variables { private_whitelist = ["10.0.0.0", "10.0.0.1", "10.0.0.2", "10.0.0.3", "10.0.0.4", "10.0.0.5", "10.0.0.6", "10.0.0.7", "10.0.0.8", "10.0.0.9", "10.0.0.10", "10.0.0.11", "10.0.0.12", "10.0.0.13", "10.0.0.14", "10.0.0.15", "10.0.0.16", "10.0.0.17", "10.0.0.18", "10.0.0.19", "10.0.0.20", "10.0.0.21", "10.0.0.22", "10.0.0.23", "10.0.0.24", "10.0.0.25", "10.0.0.26", "10.0.0.27", "10.0.0.28", "10.0.0.29", "10.0.0.30", "10.0.0.31", "10.0.0.32", "10.0.0.33", "10.0.0.34", "10.0.0.35", "10.0.0.36", "10.0.0.37", "10.0.0.38", "10.0.0.39", "10.0.0.40", "10.0.0.41", "10.0.0.42", "10.0.0.43", "10.0.0.44", "10.0.0.45", "10.0.0.46", "10.0.0.47", "10.0.0.48", "10.0.0.49", "10.0.0.50", "10.0.0.51", "10.0.0.52", "10.0.0.53", "10.0.0.54", "10.0.0.55", "10.0.0.56", "10.0.0.57", "10.0.0.58", "10.0.0.59", "10.0.0.60", "10.0.0.61", "10.0.0.62", "10.0.0.63", "10.0.0.64", "10.0.0.65", "10.0.0.66", "10.0.0.67", "10.0.0.68", "10.0.0.69", "10.0.0.70", "10.0.0.71", "10.0.0.72", "10.0.0.73", "10.0.0.74", "10.0.0.75", "10.0.0.76", "10.0.0.77", "10.0.0.78", "10.0.0.79", "10.0.0.80", "10.0.0.81", "10.0.0.82", "10.0.0.83", "10.0.0.84", "10.0.0.85", "10.0.0.86", "10.0.0.87", "10.0.0.88", "10.0.0.89", "10.0.0.90", "10.0.0.91", "10.0.0.92", "10.0.0.93", "10.0.0.94", "10.0.0.95", "10.0.0.96", "10.0.0.97", "10.0.0.98", "10.0.0.99", "10.0.0.100", "10.0.0.101", "10.0.0.102", "10.0.0.103", "10.0.0.104", "10.0.0.105", "10.0.0.106", "10.0.0.107", "10.0.0.108", "10.0.0.109", "10.0.0.110", "10.0.0.111", "10.0.0.112", "10.0.0.113", "10.0.0.114", "10.0.0.115", "10.0.0.116", "10.0.0.117", "10.0.0.118", "10.0.0.119", "10.0.0.120", "10.0.0.121", "10.0.0.122", "10.0.0.123", "10.0.0.124", "10.0.0.125", "10.0.0.126", "10.0.0.127", "10.0.0.128", "10.0.0.129", "10.0.0.130", "10.0.0.131", "10.0.0.132", "10.0.0.133", "10.0.0.134", "10.0.0.135", "10.0.0.136", "10.0.0.137", "10.0.0.138", "10.0.0.139", "10.0.0.140", "10.0.0.141", "10.0.0.142", "10.0.0.143", "10.0.0.144", "10.0.0.145", "10.0.0.146", "10.0.0.147", "10.0.0.148", "10.0.0.149", "10.0.0.150", "10.0.0.151", "10.0.0.152", "10.0.0.153", "10.0.0.154", "10.0.0.155", "10.0.0.156", "10.0.0.157", "10.0.0.158", "10.0.0.159", "10.0.0.160", "10.0.0.161", "10.0.0.162", "10.0.0.163", "10.0.0.164", "10.0.0.165", "10.0.0.166", "10.0.0.167", "10.0.0.168", "10.0.0.169", "10.0.0.170", "10.0.0.171", "10.0.0.172", "10.0.0.173", "10.0.0.174", "10.0.0.175", "10.0.0.176", "10.0.0.177", "10.0.0.178", "10.0.0.179", "10.0.0.180", "10.0.0.181", "10.0.0.182", "10.0.0.183", "10.0.0.184", "10.0.0.185", "10.0.0.186", "10.0.0.187", "10.0.0.188", "10.0.0.189", "10.0.0.190", "10.0.0.191", "10.0.0.192", "10.0.0.193", "10.0.0.194", "10.0.0.195", "10.0.0.196", "10.0.0.197", "10.0.0.198", "10.0.0.199", "10.0.0.200", "10.0.0.201", "10.0.0.202", "10.0.0.203", "10.0.0.204", "10.0.0.205", "10.0.0.206", "10.0.0.207", "10.0.0.208", "10.0.0.209", "10.0.0.210", "10.0.0.211", "10.0.0.212", "10.0.0.213", "10.0.0.214", "10.0.0.215", "10.0.0.216", "10.0.0.217", "10.0.0.218", "10.0.0.219", "10.0.0.220", "10.0.0.221", "10.0.0.222", "10.0.0.223", "10.0.0.224", "10.0.0.225", "10.0.0.226", "10.0.0.227", "10.0.0.228", "10.0.0.229", "10.0.0.230", "10.0.0.231", "10.0.0.232", "10.0.0.233", "10.0.0.234", "10.0.0.235", "10.0.0.236", "10.0.0.237", "10.0.0.238", "10.0.0.239", "10.0.0.240", "10.0.0.241", "10.0.0.242", "10.0.0.243", "10.0.0.244", "10.0.0.245", "10.0.0.246", "10.0.0.247", "10.0.0.248", "10.0.0.249", "10.0.0.250", "10.0.0.251", "10.0.0.252", "10.0.0.253", "10.0.0.254", "10.0.0.255", "10.0.1.0", "10.0.1.1", "10.0.1.2", "10.0.1.3", "10.0.1.4", "10.0.1.5", "10.0.1.6", "10.0.1.7", "10.0.1.8", "10.0.1.9", "10.0.1.10", "10.0.1.11", "10.0.1.12", "10.0.1.13", "10.0.1.14", "10.0.1.15", "10.0.1.16", "10.0.1.17", "10.0.1.18", "10.0.1.19", "10.0.1.20", "10.0.1.21", "10.0.1.22", "10.0.1.23", "10.0.1.24", "10.0.1.25", "10.0.1.26", "10.0.1.27", "10.0.1.28", "10.0.1.29", "10.0.1.30", "10.0.1.31", "10.0.1.32", "10.0.1.33", "10.0.1.34", "10.0.1.35", "10.0.1.36", "10.0.1.37", "10.0.1.38", "10.0.1.39", "10.0.1.40", "10.0.1.41", "10.0.1.42", "10.0.1.43", "10.0.1.44"] }
  expect_failures = [var.private_whitelist]
}
