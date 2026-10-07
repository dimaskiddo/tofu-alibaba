locals {
  name = "rt-2-c1-example-stage"
  tags = { product = "example" }
  vpc  = "vpc-2-c1-example-stage"

  routes = {
    to-spoke     = { destination_cidrblock = "10.0.0.0/16", nexthop_type = "VpcPeer", nexthop = "peer-1-c1-example-stage", description = "vpc-1 via peer-1" }
    to-cen-spoke = { destination_cidrblock = "10.200.0.0/16", nexthop_type = "Attachment", nexthop = "tra-2-c1-example-stage", description = "vpc-3 via cen-1" }
  }
}
