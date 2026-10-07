locals {
  name    = "dnat-1-c1-example-stage"
  tags    = { product = "example" }
  nat     = "nat-1-c1-example-stage"
  eip     = "eip-dnat-1-c1-example-stage"
  backend = "app-1-c1-example-stage"
  mappings = [
    { name = "dnat-http", external_port = "80", internal_port = "80", ip_protocol = "tcp" },
  ]
}
