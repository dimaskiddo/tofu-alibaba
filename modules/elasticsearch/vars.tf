variable "name" {
  type        = string
  description = "Instance name (sent as description), <component>-<instance>-c1-<tenant>-<env>."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", var.name))
    error_message = "name must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }
}

variable "es_version" {
  type        = string
  description = "Elasticsearch version such as 7.10_with_X-Pack or 8.5.1_with_X-Pack (ForceNew)."

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+(\\.[0-9]+)?_with_X-Pack$", var.es_version))
    error_message = "es_version must look like 7.10_with_X-Pack or 8.5.1_with_X-Pack."
  }
}

variable "vswitch_id" {
  type        = string
  description = "vSwitch of the instance (ForceNew). With zone_count above 1 Alibaba Cloud picks the other zones itself."

  validation {
    condition     = can(regex("^vsw-", var.vswitch_id))
    error_message = "vswitch_id must be a vSwitch ID (vsw-...)."
  }
}

variable "zone_count" {
  type        = number
  description = "Number of availability zones, 1-3 (ForceNew). Above 1 needs master_node_spec."
  default     = 1
  nullable    = false

  validation {
    condition     = contains([1, 2, 3], var.zone_count)
    error_message = "zone_count must be 1, 2 or 3."
  }

  validation {
    condition     = var.zone_count == 1 || var.master_node_spec != null
    error_message = "A multi-zone instance needs dedicated master nodes: set master_node_spec."
  }
}

variable "data_node" {
  type = object({
    spec              = string
    amount            = number
    disk              = number
    disk_type         = optional(string, "cloud_essd")
    performance_level = optional(string)
  })
  description = "Data nodes. amount is 2-50 and a multiple of zone_count; disk is GB; performance_level (PL1-PL3) is required for cloud_essd and rejected otherwise."
  nullable    = false

  validation {
    condition     = trimspace(var.data_node.spec) != ""
    error_message = "data_node.spec must not be empty."
  }

  validation {
    condition     = var.data_node.amount == floor(var.data_node.amount) && var.data_node.amount >= 2 && var.data_node.amount <= 50
    error_message = "data_node.amount must be a whole number from 2 to 50."
  }

  validation {
    condition     = var.data_node.amount % var.zone_count == 0
    error_message = "data_node.amount must be a multiple of zone_count."
  }

  validation {
    condition     = var.data_node.disk == floor(var.data_node.disk) && var.data_node.disk >= 20
    error_message = "data_node.disk must be a whole number of at least 20 GB."
  }

  validation {
    condition     = contains(["cloud_ssd", "cloud_essd", "cloud_efficiency"], var.data_node.disk_type)
    error_message = "data_node.disk_type must be cloud_ssd, cloud_essd or cloud_efficiency (ForceNew)."
  }

  validation {
    condition     = var.data_node.disk_type == "cloud_essd" ? contains(["PL1", "PL2", "PL3"], coalesce(var.data_node.performance_level, "none")) : var.data_node.performance_level == null
    error_message = "data_node.performance_level must be PL1, PL2 or PL3 for cloud_essd and unset for the other disk types."
  }
}

variable "master_node_spec" {
  type        = string
  description = "Spec of the 3 dedicated master nodes (20 GB cloud_ssd, the only master disk type). Null means none; required when zone_count is above 1. Master amount, disk and disk_type are ForceNew."
  default     = null

  validation {
    condition     = var.master_node_spec == null || trimspace(var.master_node_spec) != ""
    error_message = "master_node_spec must not be empty; use null for no dedicated masters."
  }
}

variable "kibana_node_spec" {
  type        = string
  description = "Spec of the Kibana node. Null creates none. Kibana stays private: public access is never enabled."
  default     = null

  validation {
    condition     = var.kibana_node_spec == null || trimspace(var.kibana_node_spec) != ""
    error_message = "kibana_node_spec must not be empty; use null for no Kibana node."
  }
}

variable "protocol" {
  type        = string
  description = "HTTP or HTTPS."
  default     = "HTTP"
  nullable    = false

  validation {
    condition     = contains(["HTTP", "HTTPS"], var.protocol)
    error_message = "protocol must be HTTP or HTTPS."
  }
}

variable "private_whitelist" {
  type        = list(string)
  description = "IPv4 addresses or CIDRs allowed to reach the private endpoint. 0.0.0.0/0 is rejected."
  nullable    = false

  validation {
    condition     = length(var.private_whitelist) >= 1 && length(var.private_whitelist) <= 300
    error_message = "private_whitelist needs 1-300 entries."
  }

  validation {
    condition = alltrue([
      for ip in var.private_whitelist : can(regex("^((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])(/(3[0-2]|[12]?[0-9]))?$", ip))
    ])
    error_message = "private_whitelist entries must be IPv4 addresses or IPv4 CIDRs."
  }

  validation {
    condition     = alltrue([for ip in var.private_whitelist : ip != "0.0.0.0" && !can(regex("/0$", ip))])
    error_message = "private_whitelist must not allow the whole internet (0.0.0.0/0)."
  }
}

variable "password" {
  type        = string
  description = "Password of the elastic account, supplied by the implementor (through the instances wrapper); never commit it. Null generates a random one (output generated_passwords)."
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
