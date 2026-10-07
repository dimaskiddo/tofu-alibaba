variable "instances" {
  type        = any
  description = "Instances keyed by resource name (the instance `name` value). Each value takes the inputs of ../ except name; its optional tags merge over the shared tags."

  validation {
    condition     = length(var.instances) >= 1
    error_message = "At least one instance is required."
  }

  validation {
    condition = alltrue([
      for n, i in var.instances : can(keys(i)) ? alltrue([for k in keys(i) : contains([
        "architecture", "engine_version", "instance_class", "storage_gb", "replication_factor", "readonly_replicas", "mongos", "shards", "config_server",
        "storage_type", "vpc_id", "vswitch_id", "zone_id", "secondary_zone_id", "hidden_zone_id", "security_ips", "deletion_protection",
        "backup", "disk_encryption_key_id", "parameters", "password_length", "tags",
      ], k)]) : false
    ])
    error_message = "Instance entries accept only architecture, engine_version, instance_class, storage_gb, replication_factor, readonly_replicas, mongos, shards, config_server, storage_type, vpc_id, vswitch_id, zone_id, secondary_zone_id, hidden_zone_id, security_ips, deletion_protection, backup, disk_encryption_key_id, parameters, password_length and tags."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every instance. At least one tag is required."
  nullable    = false

  validation {
    condition     = length(var.tags) >= 1
    error_message = "At least one tag is required."
  }

  validation {
    condition     = alltrue([for k, v in var.tags : length(k) > 0 && length(v) > 0])
    error_message = "Tag keys and values must not be empty."
  }
}

variable "mongodb_passwords" {
  type        = map(string)
  description = "Root-account passwords keyed by instance name. Supplied by the implementor; never commit them. An instance without an entry gets a random password."
  default     = {}
  nullable    = false
  sensitive   = true

  validation {
    condition     = alltrue([for n in nonsensitive(keys(var.mongodb_passwords)) : contains(keys(var.instances), n)])
    error_message = "mongodb_passwords has a key that is not an instance name; the password would be ignored and a random one generated instead."
  }
}
