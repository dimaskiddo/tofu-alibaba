locals {
  name        = "vpc-1-c1-example-stage"
  tags        = { product = "example" }
  cidr_block  = "10.0.0.0/16"
  description = "Example stage VPC"
}
