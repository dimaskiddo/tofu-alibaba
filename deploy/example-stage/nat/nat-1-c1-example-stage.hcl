locals {
  name         = "nat-1-c1-example-stage"
  tags         = { product = "example" }
  network_type = "internet"
  vpc          = "vpc-1-c1-example-stage"
  subnet       = "subnet-a-1-c1-example-stage"
  eips         = ["eip-snat-1-c1-example-stage", "eip-dnat-1-c1-example-stage"]
  description  = "Example stage public NAT gateway"
}
