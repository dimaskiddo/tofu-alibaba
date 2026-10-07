locals {
  name             = "rds-1-c1-example-stage"
  tags             = { product = "example" }
  vpc              = "vpc-1-c1-example-stage"
  engine           = "MySQL"
  engine_version   = "8.0"
  category         = "Basic"
  instance_storage = 20
  instance_type    = "mysql.n2.medium.1"

  # Basic has no standby: one placement. Allowed clients default to the VPC CIDR.
  placement = [{ zone_id = "ap-southeast-5a", subnet = "subnet-a-1-c1-example-stage" }]

  # Needs the account-wide AliyunRDSInstanceEncryptionDefaultRole (see README prerequisites).
  kms_key = "kms-2-c1-example-stage"

  databases = [{ name = "app", character_set = "utf8mb4" }]
  accounts  = [{ name = "app", privilege = "ReadWrite", databases = ["app"] }]
}
