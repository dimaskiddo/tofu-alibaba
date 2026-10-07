locals {
  name       = "dnat-2-c1-example-stage"
  tags       = { product = "example" }
  nat        = "nat-2-c1-example-stage"
  transit_ip = "dnat-2-c1-example-stage"
  backend    = "app-1-c1-example-stage"
  mappings = [
    { name = "dnat-app", external_port = "8080", internal_port = "80", ip_protocol = "tcp" },
  ]
}
