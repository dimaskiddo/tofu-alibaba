locals {
  name          = "peer-1-c1-example-stage"
  tags          = { product = "example" }
  description   = "Example stage spoke to hub peering"
  vpc           = "vpc-1-c1-example-stage"
  accepting_vpc = "vpc-2-c1-example-stage"
  # The peer-CIDR routes are owned by the route-table stack; remove this line to let the
  # peering add them to both system route tables instead (never both, duplicate destinations are rejected).
  routes = false
  # accepting_region_id defaults to the stage region; set it for an inter-region peering, together
  # with bandwidth and link_type. The accepter-side route is then added by a route-table stack in that region.
}
