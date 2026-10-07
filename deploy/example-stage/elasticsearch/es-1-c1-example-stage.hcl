locals {
  name       = "es-1-c1-example-stage"
  tags       = { product = "example" }
  vpc        = "vpc-1-c1-example-stage"
  subnet     = "subnet-a-1-c1-example-stage"
  es_version = "7.10_with_X-Pack"

  # Two zones need dedicated masters. Public access is always off; clients default to the VPC CIDR.
  zone_count = 2

  # Node specs are region specific; the amount must be a multiple of zone_count.
  data_node = {
    spec              = "elasticsearch.sn2ne.large"
    amount            = 2
    disk              = 20
    performance_level = "PL1"
  }
  master_node_spec = "elasticsearch.sn2ne.large"
  kibana_node_spec = "elasticsearch.n4.small"
}
