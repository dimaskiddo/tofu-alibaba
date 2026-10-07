locals {
  name             = "rds-2-c1-example-stage"
  tags             = { product = "example" }
  vpc              = "vpc-1-c1-example-stage"
  engine           = "PostgreSQL"
  engine_version   = "15.0"
  category         = "HighAvailability"
  instance_storage = 50
  instance_type    = "pg.n2.medium.2c"

  # Primary first, standby second, in distinct zones.
  placement = [
    { zone_id = "ap-southeast-5a", subnet = "subnet-a-1-c1-example-stage" },
    { zone_id = "ap-southeast-5b", subnet = "subnet-b-1-c1-example-stage" },
  ]

  kms_key = "kms-2-c1-example-stage"

  storage_auto_scale = { threshold = 20, upper_bound = 200 }
  maintain_time      = "18:00Z-19:00Z"

  databases = [{ name = "app", character_set = "UTF8,C,en_US.utf8" }]
  accounts  = [{ name = "app", privilege = "DBOwner", databases = ["app"] }]
}
