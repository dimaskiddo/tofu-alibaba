variable "name" {
  type        = string
  description = "Instance name, <component>-<instance>-c1-<tenant>-<env>."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,78}[a-z0-9]$", var.name))
    error_message = "name must be 2-80 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }
}

variable "instance_type" {
  type        = string
  description = "Redis for Redis OSS (alicloud_kvstore_instance), or tair_rdb / tair_scm / tair_essd for Tair (alicloud_redis_tair_instance). Changing it destroys and recreates the instance."

  validation {
    condition     = contains(["Redis", "tair_rdb", "tair_scm", "tair_essd"], var.instance_type)
    error_message = "instance_type must be Redis, tair_rdb, tair_scm or tair_essd."
  }
}

variable "engine_version" {
  type        = string
  description = "Redis 5.0, 6.0 or 7.0; tair_rdb 5.0, 6.0 or 7.0; tair_scm 1.0; tair_essd 1.0 or 2.0."

  validation {
    condition     = contains(lookup({ Redis = ["5.0", "6.0", "7.0"], tair_rdb = ["5.0", "6.0", "7.0"], tair_scm = ["1.0"], tair_essd = ["1.0", "2.0"] }, var.instance_type, []), var.engine_version)
    error_message = "engine_version is not supported for this instance_type (Redis and tair_rdb: 5.0, 6.0, 7.0; tair_scm: 1.0; tair_essd: 1.0, 2.0)."
  }
}

variable "instance_class" {
  type        = string
  description = "Instance class, region specific, e.g. redis.master.small.default or tair.rdb.2g. List the classes the region sells before choosing."

  validation {
    condition     = trimspace(var.instance_class) != ""
    error_message = "instance_class must not be empty."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC ID. Required for Tair (ForceNew); Redis OSS derives the VPC from vswitch_id and ignores it."
  default     = null

  validation {
    condition     = var.vpc_id == null || can(regex("^vpc-", var.vpc_id))
    error_message = "vpc_id must be a VPC ID (vpc-...)."
  }

  validation {
    condition     = var.instance_type == "Redis" || var.vpc_id != null
    error_message = "vpc_id is required for Tair instance types."
  }
}

variable "vswitch_id" {
  type        = string
  description = "vSwitch of the primary zone (ForceNew on Tair)."

  validation {
    condition     = can(regex("^vsw-", var.vswitch_id))
    error_message = "vswitch_id must be a vSwitch ID (vsw-...)."
  }
}

variable "zone_id" {
  type        = string
  description = "Primary availability zone (ForceNew on Tair)."

  validation {
    condition     = var.zone_id != ""
    error_message = "zone_id is required."
  }
}

variable "secondary_zone_id" {
  type        = string
  description = "Standby zone for a cross-zone instance. Null keeps the instance in one zone. ForceNew on Tair; which classes support it varies by region."
  default     = null

  validation {
    condition     = var.secondary_zone_id == null || var.secondary_zone_id != var.zone_id
    error_message = "secondary_zone_id must differ from zone_id."
  }
}

variable "shard_count" {
  type        = number
  description = "Number of shards of a cluster instance. Null keeps the class default. Redis OSS 2-256, Tair 2-32."
  default     = null

  validation {
    condition     = var.shard_count == null || (var.shard_count == floor(var.shard_count) && var.shard_count >= 2 && var.shard_count <= (var.instance_type == "Redis" ? 256 : 32))
    error_message = "shard_count must be a whole number from 2 to 256 for Redis and from 2 to 32 for Tair."
  }
}

variable "storage_size_gb" {
  type        = number
  description = "Disk size in GB of an ESSD Tair instance (tair_essd with engine_version 1.0); required there, rejected elsewhere. ForceNew."
  default     = null

  validation {
    condition     = var.storage_size_gb == null || (var.storage_size_gb == floor(var.storage_size_gb) && var.storage_size_gb > 0)
    error_message = "storage_size_gb must be a positive whole number."
  }

  validation {
    condition     = (var.storage_size_gb != null) == (var.instance_type == "tair_essd" && var.engine_version == "1.0")
    error_message = "storage_size_gb is required for tair_essd 1.0 (ESSD) and not allowed for any other instance_type or engine_version."
  }
}

variable "storage_performance_level" {
  type        = string
  description = "ESSD performance level PL1, PL2 or PL3 of tair_essd 1.0; which level a class accepts varies (PL1 4C-16C, PL2 8C-52C, PL3 16C-52C). Null keeps the Alibaba default. ForceNew."
  default     = null

  validation {
    condition     = var.storage_performance_level == null || contains(["PL1", "PL2", "PL3"], var.storage_performance_level)
    error_message = "storage_performance_level must be PL1, PL2 or PL3."
  }

  validation {
    condition     = var.storage_performance_level == null || (var.instance_type == "tair_essd" && var.engine_version == "1.0")
    error_message = "storage_performance_level only applies to tair_essd 1.0 (ESSD)."
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
}

variable "deletion_protection" {
  type        = bool
  description = "Release protection of a Redis OSS instance; null means false. Tair has no such field, so it must stay null there."
  default     = null

  validation {
    condition     = var.deletion_protection == null || var.instance_type == "Redis"
    error_message = "deletion_protection is only supported for instance_type Redis; the Tair resource has no release protection."
  }
}

variable "password" {
  type        = string
  description = "Password of the default account, supplied by the implementor (through the instances wrapper); never commit it. Null generates a random one (output generated_passwords)."
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
