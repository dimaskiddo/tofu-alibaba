variable "name" {
  type        = string
  description = "Instance name, <component>-<instance>-c1-<tenant>-<env>."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,254}[a-z0-9]$", var.name))
    error_message = "name must be 2-256 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }
}

variable "architecture" {
  type        = string
  description = "replica_set (alicloud_mongodb_instance) or sharded (alicloud_mongodb_sharding_instance). Changing it destroys the instance and creates the other kind."

  validation {
    condition     = contains(["replica_set", "sharded"], var.architecture)
    error_message = "architecture must be replica_set or sharded."
  }
}

variable "engine_version" {
  type        = string
  description = "MongoDB version: 4.0, 4.2, 4.4, 5.0, 6.0, 7.0 or 8.0."

  validation {
    condition     = contains(["4.0", "4.2", "4.4", "5.0", "6.0", "7.0", "8.0"], var.engine_version)
    error_message = "engine_version must be one of 4.0, 4.2, 4.4, 5.0, 6.0, 7.0, 8.0."
  }
}

variable "instance_class" {
  type        = string
  description = "replica_set only: node class, region specific, e.g. mdb.shard.2x.xlarge.d. List what the region sells before choosing."
  default     = null

  validation {
    condition     = var.architecture == "replica_set" ? (var.instance_class == null ? false : trimspace(var.instance_class) != "") : var.instance_class == null
    error_message = "instance_class is required (not empty) for replica_set and not allowed for sharded; use mongos[*].node_class and shards[*].node_class there."
  }
}

variable "storage_gb" {
  type        = number
  description = "replica_set only: disk size in GB per node, a multiple of 10. Allowed range depends on the class."
  default     = null

  validation {
    condition     = var.architecture == "replica_set" ? (var.storage_gb == null ? false : var.storage_gb == floor(var.storage_gb) && var.storage_gb >= 10 && var.storage_gb % 10 == 0) : var.storage_gb == null
    error_message = "storage_gb is required for replica_set (a whole multiple of 10, at least 10) and not allowed for sharded; use shards[*].node_storage there."
  }
}

variable "replication_factor" {
  type        = number
  description = "replica_set only: number of nodes, 1 (standalone), 3, 5 or 7. Null keeps the Alibaba default."
  default     = null

  validation {
    condition     = var.replication_factor == null || (var.architecture == "replica_set" && contains([1, 3, 5, 7], var.replication_factor))
    error_message = "replication_factor must be 1, 3, 5 or 7 and only applies to replica_set."
  }
}

variable "readonly_replicas" {
  type        = number
  description = "replica_set only: read-only nodes, 0-5. Null keeps the Alibaba default. Sharded sets them per shard in shards[*]."
  default     = null

  validation {
    condition     = var.readonly_replicas == null || (var.architecture == "replica_set" && var.readonly_replicas == floor(var.readonly_replicas) && var.readonly_replicas >= 0 && var.readonly_replicas <= 5)
    error_message = "readonly_replicas must be a whole number from 0 to 5 and only applies to replica_set."
  }
}

variable "mongos" {
  type = list(object({
    node_class = string
  }))
  description = "sharded only: mongos routers, 2-32 entries."
  default     = []
  nullable    = false

  validation {
    condition     = var.architecture == "sharded" ? length(var.mongos) >= 2 && length(var.mongos) <= 32 && alltrue([for m in var.mongos : trimspace(m.node_class) != ""]) : length(var.mongos) == 0
    error_message = "sharded needs 2-32 mongos entries with a node_class; replica_set must leave mongos empty."
  }
}

variable "shards" {
  type = list(object({
    node_class        = string
    node_storage      = number
    readonly_replicas = optional(number)
  }))
  description = "sharded only: shard nodes, 2-32 entries. node_storage is GB, a multiple of 10; readonly_replicas 0-5."
  default     = []
  nullable    = false

  validation {
    condition = var.architecture == "sharded" ? (
      length(var.shards) >= 2 && length(var.shards) <= 32 && alltrue([
        for s in var.shards : trimspace(s.node_class) != "" &&
        s.node_storage == floor(s.node_storage) && s.node_storage >= 10 && s.node_storage % 10 == 0 &&
        (s.readonly_replicas == null ? true : s.readonly_replicas == floor(s.readonly_replicas) && s.readonly_replicas >= 0 && s.readonly_replicas <= 5)
      ])
    ) : length(var.shards) == 0
    error_message = "sharded needs 2-32 shards with a node_class, a node_storage that is a multiple of 10 and readonly_replicas 0-5; replica_set must leave shards empty."
  }
}

variable "config_server" {
  type = object({
    node_class   = string
    node_storage = number
  })
  description = "sharded only: config server. Null keeps the Alibaba default. ForceNew."
  default     = null

  validation {
    condition     = var.config_server == null ? true : var.architecture == "sharded" && trimspace(var.config_server.node_class) != "" && var.config_server.node_storage == floor(var.config_server.node_storage) && var.config_server.node_storage >= 10 && var.config_server.node_storage % 10 == 0
    error_message = "config_server only applies to sharded and needs a node_class and a node_storage that is a multiple of 10."
  }
}

variable "storage_type" {
  type        = string
  description = "cloud_essd1, cloud_essd2, cloud_essd3, cloud_auto (China site only) or local_ssd. Null keeps the Alibaba default: cloud_essd1 from 4.4, local_ssd for 4.0 and 4.2. Secondary zone, hidden zone and disk encryption need a cloud disk."
  default     = null

  validation {
    condition     = var.storage_type == null || contains(["cloud_essd1", "cloud_essd2", "cloud_essd3", "cloud_auto", "local_ssd"], var.storage_type)
    error_message = "storage_type must be cloud_essd1, cloud_essd2, cloud_essd3, cloud_auto or local_ssd."
  }

  validation {
    condition     = (var.storage_type == "local_ssd" || (var.storage_type == null && contains(["4.0", "4.2"], var.engine_version))) ? var.secondary_zone_id == null && var.hidden_zone_id == null && var.disk_encryption_key_id == null : true
    error_message = "secondary_zone_id, hidden_zone_id and disk_encryption_key_id need a cloud disk; set storage_type to a cloud_* value (4.0 and 4.2 default to local_ssd)."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC ID (ForceNew)."

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "vpc_id must be a VPC ID (vpc-...)."
  }
}

variable "vswitch_id" {
  type        = string
  description = "vSwitch of the primary zone (ForceNew)."

  validation {
    condition     = can(regex("^vsw-", var.vswitch_id))
    error_message = "vswitch_id must be a vSwitch ID (vsw-...)."
  }
}

variable "zone_id" {
  type        = string
  description = "Primary availability zone (ForceNew)."

  validation {
    condition     = var.zone_id != ""
    error_message = "zone_id is required."
  }
}

variable "secondary_zone_id" {
  type        = string
  description = "Zone of the secondary node for a multi-zone instance; cloud disk only. Null keeps the instance in one zone."
  default     = null

  validation {
    condition     = var.secondary_zone_id == null || var.secondary_zone_id != var.zone_id
    error_message = "secondary_zone_id must differ from zone_id."
  }
}

variable "hidden_zone_id" {
  type        = string
  description = "Zone of the hidden node for a multi-zone instance; cloud disk only. Must differ from zone_id and secondary_zone_id. Null keeps the Alibaba default."
  default     = null

  validation {
    condition     = var.hidden_zone_id == null || (var.hidden_zone_id != var.zone_id && var.hidden_zone_id != var.secondary_zone_id)
    error_message = "hidden_zone_id must differ from zone_id and secondary_zone_id."
  }
}

variable "security_ips" {
  type        = list(string)
  description = "IPv4 addresses or CIDRs allowed to connect. 0.0.0.0/0 is rejected."
  nullable    = false

  validation {
    condition     = length(var.security_ips) >= 1 && length(var.security_ips) <= 1000
    error_message = "security_ips needs 1-1000 entries."
  }

  validation {
    condition = alltrue([
      for ip in var.security_ips : can(regex("^((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])(/(3[0-2]|[12]?[0-9]))?$", ip))
    ])
    error_message = "security_ips entries must be IPv4 addresses or IPv4 CIDRs."
  }

  validation {
    condition     = alltrue([for ip in var.security_ips : ip != "0.0.0.0" && !can(regex("/0$", ip))])
    error_message = "security_ips must not allow the whole internet (0.0.0.0/0)."
  }

  validation {
    condition     = length(distinct(var.security_ips)) == length(var.security_ips)
    error_message = "security_ips must not contain duplicates; the API rejects them."
  }
}

variable "deletion_protection" {
  type        = bool
  description = "Release protection."
  default     = false
  nullable    = false
}

variable "password" {
  type        = string
  description = "Password of the root account, supplied by the implementor (through the instances wrapper); never commit it. Null generates a random one (output generated_passwords)."
  default     = null
  sensitive   = true

  validation {
    condition = var.password == null || nonsensitive(
      can(regex("^[A-Za-z0-9!@#$%^&*()_+=-]{8,32}$", var.password)) &&
      length([for r in ["[a-z]", "[A-Z]", "[0-9]", "[!@#$%^&*()_+=-]"] : r if can(regex(r, var.password))]) >= 3
    )
    error_message = "The password must be 8-32 characters from letters, digits and !@#$%^&*()_+=-, using at least 3 of: lower case, upper case, digit, special character."
  }
}

variable "password_length" {
  type        = number
  description = "Length of the generated password (letters and digits)."
  default     = 16
  nullable    = false

  validation {
    condition     = var.password_length == floor(var.password_length) && var.password_length >= 8 && var.password_length <= 32
    error_message = "password_length must be a whole number from 8 to 32."
  }
}

variable "backup" {
  type = object({
    period         = list(string)
    time           = string
    retention_days = optional(number)
  })
  description = "Backup policy: period is weekday names (Monday...Sunday), time a one-hour UTC window like 02:00Z-03:00Z, retention_days the full-backup retention. Null keeps the Alibaba default."
  default     = null

  validation {
    condition     = var.backup == null ? true : length(var.backup.period) >= 1 && length(distinct(var.backup.period)) == length(var.backup.period) && alltrue([for d in var.backup.period : contains(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], d)])
    error_message = "backup.period needs at least one distinct weekday name (Monday ... Sunday)."
  }

  validation {
    condition     = var.backup == null ? true : contains([for h in range(24) : format("%02d:00Z-%02d:00Z", h, h + 1)], var.backup.time)
    error_message = "backup.time must be a one-hour UTC window starting on the hour, e.g. 02:00Z-03:00Z."
  }

  validation {
    condition     = var.backup == null ? true : (var.backup.retention_days == null ? true : var.backup.retention_days == floor(var.backup.retention_days) && var.backup.retention_days >= 1)
    error_message = "backup.retention_days must be a whole number of at least 1."
  }
}

variable "disk_encryption_key_id" {
  type        = string
  description = "KMS key ID for cloud-disk encryption. ForceNew, so it can only be set at creation. Disabling or deleting the key locks the instance. Needs a cloud disk."
  default     = null

  validation {
    condition     = var.disk_encryption_key_id == null || trimspace(var.disk_encryption_key_id) != ""
    error_message = "disk_encryption_key_id must not be empty."
  }
}

variable "parameters" {
  type        = map(string)
  description = "Database parameters applied after launch, name to value. Names the engine does not know fail at apply."
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for k, v in var.parameters : length(k) > 0 && length(v) > 0])
    error_message = "Parameter names and values must not be empty."
  }
}

variable "tags" {
  type        = map(string)
  description = "Resource tags. At least one tag is required."
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
