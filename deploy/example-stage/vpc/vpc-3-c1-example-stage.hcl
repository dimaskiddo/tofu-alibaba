locals {
  name        = "vpc-3-c1-example-stage"
  cidr_block  = "10.200.0.0/16"
  description = "Example stage CEN spoke VPC"
  tags        = { product = "example" }
}
