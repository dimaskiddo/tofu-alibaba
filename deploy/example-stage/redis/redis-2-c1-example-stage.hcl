locals {
  name           = "redis-2-c1-example-stage"
  tags           = { product = "example" }
  vpc            = "vpc-1-c1-example-stage"
  subnet         = "subnet-b-1-c1-example-stage"
  instance_type  = "tair_rdb"
  engine_version = "7.0"
  instance_class = "tair.rdb.2g"
  zone_id        = "ap-southeast-5b"

  # Tair has no release protection field, so deletion_protection stays unset.
  password_length = 24
}
