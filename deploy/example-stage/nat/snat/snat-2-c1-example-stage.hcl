locals {
  name       = "snat-2-c1-example-stage"
  tags       = { product = "example" }
  nat        = "nat-2-c1-example-stage"
  transit_ip = "snat-2-c1-example-stage"
  sources    = ["subnet-b-1-c1-example-stage"]
}
