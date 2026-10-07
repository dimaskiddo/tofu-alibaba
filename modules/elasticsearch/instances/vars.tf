variable "instances" {
  type        = any
  description = "Instances keyed by resource name (the instance `name` value). Each value takes the inputs of ../ except name; its optional tags merge over the shared tags."

  validation {
    condition     = length(var.instances) >= 1
    error_message = "At least one instance is required."
  }

  validation {
    condition = alltrue([
      for n, i in var.instances : can(keys(i)) ? alltrue([for k in keys(i) : contains(["es_version", "vswitch_id", "zone_count", "data_node", "master_node_spec", "kibana_node_spec", "protocol", "private_whitelist", "password_length", "tags"], k)]) : false
    ])
    error_message = "Instance entries accept only es_version, vswitch_id, zone_count, data_node, master_node_spec, kibana_node_spec, protocol, private_whitelist, password_length and tags."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [try(length(setsubtract(keys(try(i.data_node, {})), ["spec", "amount", "disk", "disk_type", "performance_level"])) == 0, false)]]))
    error_message = "data_node: accepted keys are spec, amount, disk, disk_type, performance_level."
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

variable "elasticsearch_passwords" {
  type        = map(string)
  description = "elastic-account passwords keyed by instance name. Supplied by the implementor; never commit them. An instance without an entry gets a random password."
  default     = {}
  nullable    = false
  sensitive   = true

  validation {
    condition     = alltrue([for n in nonsensitive(keys(var.elasticsearch_passwords)) : contains(keys(var.instances), n)])
    error_message = "elasticsearch_passwords has a key that is not an instance name; the password would be ignored and a random one generated instead."
  }
}
