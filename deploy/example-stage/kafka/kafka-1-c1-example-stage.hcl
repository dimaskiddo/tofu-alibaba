locals {
  name          = "kafka-1-c1-example-stage"
  tags          = { product = "example" }
  vpc           = "vpc-1-c1-example-stage"
  partition_num = 50
  disk_type     = "ssd"
  disk_size     = 500

  # Traffic specs are region specific. SASL users need a professional edition.
  io_max_spec     = "alikafka.hw.2xlarge"
  spec_type       = "professional"
  service_version = "2.2.0"

  # Single zone; a second entry makes the instance multi-zone. Allowed clients default to the VPC CIDR.
  placement = [{ zone_id = "ap-southeast-5a", subnet = "subnet-a-1-c1-example-stage" }]

  topics = [
    { name = "orders", partition_num = 12, remark = "orders" },
    { name = "events", partition_num = 6 },
  ]
  consumer_groups = [{ name = "app" }]

  sasl_users = [{
    name = "app"
    acls = [
      { resource_type = "Topic", resource_name = "orders", operation = "Write" },
      { resource_type = "Topic", resource_name = "orders", operation = "Read" },
      { resource_type = "Group", resource_name = "app", operation = "Read" },
    ]
  }]
}
