locals {
  name = "rt-3-c1-example-stage"
  tags = { product = "example" }
  vpc  = "vpc-3-c1-example-stage"

  routes = {
    to-hub = { destination_cidrblock = "10.100.0.0/16", nexthop_type = "Attachment", nexthop = "tra-3-c1-example-stage", description = "vpc-2 via cen-1" }
  }
}
