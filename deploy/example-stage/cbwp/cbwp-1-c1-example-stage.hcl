locals {
  name      = "cbwp-1-c1-example-stage"
  tags      = { product = "example" }
  bandwidth = 20

  # EIP names from eip, ALB names from slb/alb (Internet-facing only).
  eips = ["eip-snat-1-c1-example-stage", "eip-dnat-1-c1-example-stage"]
  albs = ["alb-2-c1-example-stage"]
}
