locals {
  name                 = "eip-snat-1-c1-example-stage"
  tags                 = { product = "example" }
  bandwidth            = 10
  internet_charge_type = "PayByTraffic"
  description          = "Public NAT SNAT Egress"
}
