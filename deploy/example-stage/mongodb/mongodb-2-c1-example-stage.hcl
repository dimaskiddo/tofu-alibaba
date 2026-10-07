locals {
  name         = "mongodb-2-c1-example-stage"
  tags         = { product = "example" }
  vpc          = "vpc-1-c1-example-stage"
  subnet       = "subnet-b-1-c1-example-stage"
  architecture = "sharded"

  engine_version = "7.0"

  # At least two mongos and two shards. Each shard is itself a three-node replica set.
  mongos = [
    { node_class = "mdb.shard.4x.large.d" },
    { node_class = "mdb.shard.4x.large.d" },
  ]
  shards = [
    { node_class = "mdb.shard.4x.large.d", node_storage = 20 },
    { node_class = "mdb.shard.4x.large.d", node_storage = 20 },
  ]
  config_server = { node_class = "mdb.shard.2x.xlarge.d", node_storage = 20 }

  zone_id = "ap-southeast-5b"

  # Encrypts the cloud disks with this key of the kms leaf; the key cannot be changed later without replacing the instance.
  kms_key = "kms-3-c1-example-stage"
}
