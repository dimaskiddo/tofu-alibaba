locals {
  name    = "snat-1-c1-example-stage"
  tags    = { product = "example" }
  nat     = "nat-1-c1-example-stage"
  eip     = "eip-snat-1-c1-example-stage"
  sources = ["subnet-a-1-c1-example-stage", "subnet-b-1-c1-example-stage"]
}
