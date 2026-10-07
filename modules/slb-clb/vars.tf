variable "name" {
  type        = string
  description = "CLB name, <component>-<instance>-c1-<tenant>-<env>."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,78}[a-z0-9]$", var.name))
    error_message = "name must be 2-80 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }
}

variable "zones" {
  type        = list(string)
  description = "Registered availability zones; master_zone_id and slave_zone_id must be among them."
  nullable    = false

  validation {
    condition     = length(var.zones) >= 1
    error_message = "At least one availability zone must be registered."
  }
}

variable "address_type" {
  type        = string
  description = "intranet = private CLB (needs vswitch_id), internet = public CLB."
  default     = "intranet"
  nullable    = false

  validation {
    condition     = contains(["intranet", "internet"], var.address_type)
    error_message = "address_type must be intranet or internet."
  }
}

variable "vswitch_id" {
  type        = string
  description = "vSwitch for the CLB. Required for intranet."
  default     = null

  validation {
    condition     = var.address_type == "internet" ? true : try(can(regex("^vsw-", var.vswitch_id)), false)
    error_message = "vswitch_id (vsw-...) is required for an intranet CLB."
  }
}

variable "master_zone_id" {
  type        = string
  description = "Primary zone. Null lets Alibaba Cloud choose; when set it must be a registered zone."
  default     = null
}

variable "slave_zone_id" {
  type        = string
  description = "Standby zone. Must differ from master_zone_id and be a registered zone."
  default     = null
}

variable "load_balancer_spec" {
  type        = string
  description = "Performance-guaranteed spec. Null keeps the shared-performance instance."
  default     = null

  validation {
    condition     = var.load_balancer_spec == null ? true : contains(["slb.s1.small", "slb.s2.small", "slb.s2.medium", "slb.s3.small", "slb.s3.medium", "slb.s3.large", "slb.s4.large"], var.load_balancer_spec)
    error_message = "load_balancer_spec must be one of slb.s1.small, slb.s2.small, slb.s2.medium, slb.s3.small, slb.s3.medium, slb.s3.large, slb.s4.large."
  }
}

variable "internet_charge_type" {
  type        = string
  description = "Only PayByTraffic: international accounts cannot create PayByBandwidth CLBs."
  default     = "PayByTraffic"
  nullable    = false

  validation {
    condition     = var.internet_charge_type == "PayByTraffic"
    error_message = "internet_charge_type must be PayByTraffic: international accounts cannot create PayByBandwidth CLBs, pay-by-spec is no longer sold and pay-by-LCU accepts only paybytraffic."
  }
}

variable "bandwidth" {
  type        = number
  description = "Kept for contract parity; must be null (PayByTraffic CLBs have no bandwidth)."
  default     = null

  validation {
    condition     = var.bandwidth == null
    error_message = "bandwidth must be null: PayByTraffic CLBs bill by traffic and the provider ignores bandwidth."
  }
}

variable "backend_servers" {
  type = map(object({
    server_id = string
    port      = number
    weight    = optional(number, 100)
    type      = optional(string, "ecs")
  }))
  description = "Backend servers keyed by name; attached to one vServer group."
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for k, s in var.backend_servers : can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", k))])
    error_message = "Backend server keys must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }

  validation {
    condition     = alltrue([for k, s in var.backend_servers : s.server_id != ""])
    error_message = "Every backend server needs a server_id."
  }

  validation {
    condition     = alltrue([for k, s in var.backend_servers : s.port == floor(s.port) && s.port >= 1 && s.port <= 65535])
    error_message = "Backend server port must be 1-65535."
  }

  validation {
    condition     = alltrue([for k, s in var.backend_servers : s.weight == floor(s.weight) && s.weight >= 0 && s.weight <= 100])
    error_message = "Backend server weight must be 0-100."
  }

  validation {
    condition     = alltrue([for k, s in var.backend_servers : contains(["ecs", "eni", "eci"], s.type)])
    error_message = "Backend server type must be ecs, eni or eci."
  }
}

variable "listeners" {
  type = map(object({
    protocol              = string
    frontend_port         = number
    backend_port          = optional(number)
    scheduler             = optional(string, "wrr")
    bandwidth             = optional(number)
    server_certificate_id = optional(string)
  }))
  description = "Listeners keyed by name. https needs server_certificate_id; backend_port is required when no backend_servers are attached."
  nullable    = false

  validation {
    condition     = length(var.listeners) >= 1
    error_message = "At least one listener is required."
  }

  validation {
    condition     = alltrue([for k, l in var.listeners : can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", k))])
    error_message = "Listener keys must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }

  validation {
    condition     = alltrue([for k, l in var.listeners : contains(["http", "https", "tcp", "udp"], l.protocol)])
    error_message = "Listener protocol must be http, https, tcp or udp."
  }

  validation {
    condition     = alltrue([for k, l in var.listeners : l.frontend_port == floor(l.frontend_port) && l.frontend_port >= 1 && l.frontend_port <= 65535])
    error_message = "Listener frontend_port must be 1-65535."
  }

  validation {
    condition     = alltrue([for k, l in var.listeners : l.backend_port == null ? true : l.backend_port == floor(l.backend_port) && l.backend_port >= 1 && l.backend_port <= 65535])
    error_message = "Listener backend_port must be 1-65535."
  }

  validation {
    condition     = length(distinct([for k, l in var.listeners : "${l.protocol == "udp" ? "udp" : "tcp"}-${l.frontend_port}"])) == length(var.listeners)
    error_message = "Listener frontend ports must be unique per transport (tcp-based http/https/tcp share one namespace; udp is separate)."
  }

  validation {
    condition = alltrue([for k, l in var.listeners : contains(
      l.protocol == "udp" ? ["wrr", "rr", "sch", "tch", "qch"] : l.protocol == "tcp" ? ["wrr", "rr", "sch", "tch"] : ["wrr", "rr"],
      l.scheduler
    )])
    error_message = "scheduler must be wrr or rr for http/https, plus sch and tch for tcp, plus sch, tch and qch for udp."
  }

  validation {
    condition     = alltrue([for k, l in var.listeners : l.bandwidth == null ? true : l.bandwidth == -1 || (l.bandwidth == floor(l.bandwidth) && l.bandwidth >= 1 && l.bandwidth <= 1000)])
    error_message = "Listener bandwidth must be -1 or 1-1000."
  }

  validation {
    condition     = alltrue([for k, l in var.listeners : l.protocol == "https" ? try(length(l.server_certificate_id) > 0, false) : true])
    error_message = "https listeners require server_certificate_id."
  }
}

variable "tags" {
  type        = map(string)
  description = "Resource tags. At least one tag is required. Listeners and attachments are not taggable in the provider."
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
