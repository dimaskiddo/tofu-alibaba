locals {
  name           = "redis-1-c1-example-stage"
  tags           = { product = "example" }
  vpc            = "vpc-1-c1-example-stage"
  subnet         = "subnet-a-1-c1-example-stage"
  instance_type  = "Redis"
  engine_version = "7.0"

  # Classes are region specific; list what ap-southeast-5 sells before applying.
  instance_class = "redis.master.small.default"

  # Master and replica in two zones. Allowed clients default to the VPC CIDR.
  zone_id           = "ap-southeast-5a"
  secondary_zone_id = "ap-southeast-5b"
}
