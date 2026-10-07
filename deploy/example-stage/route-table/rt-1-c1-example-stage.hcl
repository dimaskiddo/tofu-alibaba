locals {
  name = "rt-1-c1-example-stage"
  tags = { product = "example" }
  # Routes go into the system route table of this VPC. Set custom = true to create a table named
  # after `name` instead, and vswitches = ["subnet-a-1-c1-example-stage"] to bind vSwitches to it;
  # they then stop using the system table, so include every route they need.
  vpc = "vpc-1-c1-example-stage"

  # nexthop is a resource name: VpcPeer -> a vpc-peering file, NatGateway -> a nat file, Attachment -> a cen attachment name.
  # Use a literal nexthop_id instead for anything not managed here.
  routes = {
    to-hub = { destination_cidrblock = "10.100.0.0/16", nexthop_type = "VpcPeer", nexthop = "peer-1-c1-example-stage", description = "vpc-2 via peer-1" }
  }
}
