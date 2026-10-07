locals {
  name        = "vpc-2-c1-example-stage"
  cidr_block  = "10.100.0.0/16"
  description = "Example stage hub VPC"
  tags        = { product = "example" }
}
