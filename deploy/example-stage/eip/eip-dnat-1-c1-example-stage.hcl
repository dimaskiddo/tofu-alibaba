locals {
  name                 = "eip-dnat-1-c1-example-stage"
  tags                 = { product = "example" }
  bandwidth            = 5
  internet_charge_type = "PayByTraffic"
  description          = "Public NAT DNAT Ingress"
}
