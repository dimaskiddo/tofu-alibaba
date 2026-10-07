variable "instances" {
  type        = any
  description = "Instances keyed by resource name (the instance `name` value). Each value takes the inputs of ../ except name; its optional tags merge over the shared tags."

  validation {
    condition     = length(var.instances) >= 1
    error_message = "At least one instance is required."
  }

  validation {
    condition = alltrue([
      for n, i in var.instances : can(keys(i)) ? alltrue([for k in keys(i) : contains(["partition_num", "disk_type", "disk_size", "io_max_spec", "spec_type", "service_version", "placement", "security_group_id", "allowed_ips", "topics", "consumer_groups", "sasl_users", "password_length", "tags"], k)]) : false
    ])
    error_message = "Instance entries accept only partition_num, disk_type, disk_size, io_max_spec, spec_type, service_version, placement, security_group_id, allowed_ips, topics, consumer_groups, sasl_users, password_length and tags."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [for x in try(i.placement, []) : try(length(setsubtract(keys(x), ["zone_id", "vswitch_id"])) == 0, false)]]))
    error_message = "placement entries: accepted keys are zone_id, vswitch_id."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [for x in coalesce(try(i.topics, null), []) : try(length(setsubtract(keys(x), ["name", "partition_num", "remark", "compact_topic", "local_topic"])) == 0, false)]]))
    error_message = "topics entries: accepted keys are name, partition_num, remark, compact_topic, local_topic."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [for x in coalesce(try(i.consumer_groups, null), []) : try(length(setsubtract(keys(x), ["name", "remark"])) == 0, false)]]))
    error_message = "consumer_groups entries: accepted keys are name, remark."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [for x in coalesce(try(i.sasl_users, null), []) : try(length(setsubtract(keys(x), ["name", "type", "acls"])) == 0, false)]]))
    error_message = "sasl_users entries: accepted keys are name, type, acls."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : flatten([for x in coalesce(try(i.sasl_users, null), []) : [for y in try(x.acls, []) : try(length(setsubtract(keys(y), ["resource_type", "resource_name", "pattern", "operation"])) == 0, false)]])]))
    error_message = "sasl_users acls: accepted keys are resource_type, resource_name, pattern, operation."
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

variable "kafka_sasl_passwords" {
  type        = map(map(string))
  description = "SASL passwords keyed by instance name, then user name. Supplied by the implementor; never commit them. A user without an entry gets a random password."
  default     = {}
  nullable    = false
  sensitive   = true

  validation {
    condition     = alltrue([for n in nonsensitive(keys(var.kafka_sasl_passwords)) : contains(keys(var.instances), n)])
    error_message = "kafka_sasl_passwords has a key that is not an instance name; the passwords would be ignored and random ones generated instead."
  }
}
