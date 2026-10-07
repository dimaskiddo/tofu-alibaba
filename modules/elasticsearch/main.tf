locals {
  generate = nonsensitive(var.password == null)
  password = local.generate ? random_password.this[0].result : var.password
}

resource "random_password" "this" {
  count = local.generate ? 1 : 0

  length      = var.password_length
  special     = false
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
}

# pay-as-you-go, private only; warm/client nodes, setting_config (drifts) and disk encryption are left out until a workload needs them.
resource "alicloud_elasticsearch_instance" "this" {
  description       = var.name
  version           = var.es_version
  vswitch_id        = var.vswitch_id
  zone_count        = var.zone_count
  payment_type      = "PayAsYouGo"
  protocol          = var.protocol
  password          = local.password
  private_whitelist = var.private_whitelist
  tags              = var.tags

  # Alibaba Cloud enables public Kibana by default; it is forced off, and Kibana is reachable on the private network only when a Kibana node exists.
  enable_public                 = false
  enable_kibana_public_network  = false
  enable_kibana_private_network = var.kibana_node_spec != null

  data_node_configuration {
    spec              = var.data_node.spec
    amount            = var.data_node.amount
    disk              = var.data_node.disk
    disk_type         = var.data_node.disk_type
    performance_level = var.data_node.performance_level
  }

  dynamic "master_configuration" {
    for_each = var.master_node_spec == null ? [] : [var.master_node_spec]
    content {
      spec      = master_configuration.value
      amount    = 3
      disk      = 20
      disk_type = "cloud_ssd"
    }
  }

  dynamic "kibana_configuration" {
    for_each = var.kibana_node_spec == null ? [] : [var.kibana_node_spec]
    content {
      spec   = kibana_configuration.value
      amount = 1
    }
  }

  # Multi-zone clusters and large disks take far longer than the provider's 61 minute default.
  timeouts {
    create = "120m"
  }
}
