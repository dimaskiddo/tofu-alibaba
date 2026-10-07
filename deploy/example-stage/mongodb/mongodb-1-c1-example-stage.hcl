locals {
  name         = "mongodb-1-c1-example-stage"
  tags         = { product = "example" }
  vpc          = "vpc-1-c1-example-stage"
  subnet       = "subnet-a-1-c1-example-stage"
  architecture = "replica_set"

  engine_version = "7.0"

  # Classes and the minimum disk are region specific; confirm what ap-southeast-5 sells before applying.
  instance_class = "mdb.shard.4x.large.d"
  storage_gb     = 20

  # Three nodes plus one read-only node. Allowed clients default to the VPC CIDR.
  replication_factor = 3
  readonly_replicas  = 1
  zone_id            = "ap-southeast-5a"

  # One-hour UTC window. Retention is in days.
  backup = {
    period         = ["Monday", "Thursday"]
    time           = "17:00Z-18:00Z"
    retention_days = 7
  }

  parameters = {
    "operationProfiling.slowOpThresholdMs" = "200"
  }
}
