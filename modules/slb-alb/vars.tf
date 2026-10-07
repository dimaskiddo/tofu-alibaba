variable "name" {
  type        = string
  description = "ALB name, <component>-<instance>-c1-<tenant>-<env>."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", var.name))
    error_message = "name must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }
}

variable "zones" {
  type        = list(string)
  description = "Registered availability zones; every zone_mappings zone_id must be one of them."
  nullable    = false

  validation {
    condition     = length(var.zones) >= 1
    error_message = "At least one availability zone must be registered."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC the ALB and its server groups belong to."

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "vpc_id must be a VPC ID (vpc-...)."
  }
}

variable "address_type" {
  type        = string
  description = "Intranet = private ALB, Internet = public ALB (Alibaba Cloud allocates the EIPs)."
  default     = "Intranet"
  nullable    = false

  validation {
    condition     = contains(["Intranet", "Internet"], var.address_type)
    error_message = "address_type must be Intranet or Internet."
  }
}

variable "load_balancer_edition" {
  type        = string
  description = "ALB edition: Basic, Standard or StandardWithWaf. No default so the billing tier is an explicit choice."

  validation {
    condition     = contains(["Basic", "Standard", "StandardWithWaf"], var.load_balancer_edition)
    error_message = "load_balancer_edition must be Basic, Standard or StandardWithWaf."
  }
}

variable "zone_mappings" {
  type = list(object({
    zone_id    = string
    vswitch_id = string
  }))
  description = "Zone and vSwitch pairs. Alibaba Cloud requires at least two zones for an ALB, one vSwitch per zone."
  nullable    = false

  validation {
    condition     = length(var.zone_mappings) >= 2
    error_message = "An ALB requires at least two zone_mappings in different zones; a single-zone ALB is not supported by Alibaba Cloud."
  }

  validation {
    condition     = length(distinct([for z in var.zone_mappings : z.zone_id])) == length(var.zone_mappings)
    error_message = "Each zone may appear only once in zone_mappings."
  }

  validation {
    condition     = alltrue([for z in var.zone_mappings : can(regex("^vsw-", z.vswitch_id))])
    error_message = "Every zone mapping needs a vswitch_id (vsw-...)."
  }

  validation {
    condition     = alltrue([for z in var.zone_mappings : z.zone_id != ""])
    error_message = "zone_id is required for every zone mapping."
  }
}

variable "server_groups" {
  type = map(object({
    protocol  = optional(string, "HTTP")
    scheduler = optional(string, "Wrr")
    sticky    = optional(bool, false)
    health_check = optional(object({
      enabled  = optional(bool, true)
      protocol = optional(string, "HTTP")
      path     = optional(string, "/")
      codes    = optional(list(string), ["http_2xx"])
      port     = optional(number, 0)
    }), {})
    servers = optional(list(object({
      server_id   = string
      server_type = optional(string, "Ecs")
      port        = number
      weight      = optional(number, 100)
    })), [])
  }))
  description = "Server groups keyed by name. port 0 in health_check means the backend server port."
  default     = {}
  nullable    = false

  validation {
    condition     = length(var.server_groups) >= 1
    error_message = "At least one server group is required."
  }

  validation {
    condition     = alltrue([for k, g in var.server_groups : can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", k))])
    error_message = "Server group keys must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }

  validation {
    condition     = alltrue([for k, g in var.server_groups : contains(["HTTP", "HTTPS", "GRPC"], g.protocol)])
    error_message = "Server group protocol must be HTTP, HTTPS or GRPC."
  }

  validation {
    condition     = alltrue([for k, g in var.server_groups : contains(["Wrr", "Wlc", "Sch"], g.scheduler)])
    error_message = "Server group scheduler must be Wrr, Wlc or Sch."
  }

  validation {
    condition     = alltrue([for k, g in var.server_groups : contains(["HTTP", "HTTPS", "TCP", "GRPC"], g.health_check.protocol)])
    error_message = "health_check protocol must be HTTP, HTTPS, TCP or GRPC."
  }

  validation {
    condition     = alltrue([for k, g in var.server_groups : g.health_check.port == floor(g.health_check.port) && g.health_check.port >= 0 && g.health_check.port <= 65535])
    error_message = "health_check port must be 0-65535."
  }

  validation {
    condition     = alltrue(flatten([for k, g in var.server_groups : [for s in g.servers : s.server_id != "" && s.port == floor(s.port) && s.port >= 1 && s.port <= 65535]]))
    error_message = "Every server needs a server_id and a port from 1 to 65535."
  }

  validation {
    condition     = alltrue(flatten([for k, g in var.server_groups : [for s in g.servers : s.weight == floor(s.weight) && s.weight >= 0 && s.weight <= 100]]))
    error_message = "Server weight must be 0-100."
  }

  validation {
    condition     = alltrue(flatten([for k, g in var.server_groups : [for s in g.servers : contains(["Ecs", "Eni", "Eci"], s.server_type)]]))
    error_message = "server_type must be Ecs, Eni or Eci."
  }
}

variable "listeners" {
  type = map(object({
    protocol             = string
    port                 = number
    default_server_group = string
    certificate_id       = optional(string)
    description          = optional(string)
  }))
  description = "Listeners keyed by name. default_server_group is a key of server_groups. HTTPS needs certificate_id."
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
    condition     = alltrue([for k, l in var.listeners : contains(["HTTP", "HTTPS"], l.protocol)])
    error_message = "Listener protocol must be HTTP or HTTPS."
  }

  validation {
    condition     = alltrue([for k, l in var.listeners : l.port == floor(l.port) && l.port >= 1 && l.port <= 65535])
    error_message = "Listener port must be 1-65535."
  }

  validation {
    condition     = length(distinct([for k, l in var.listeners : l.port])) == length(var.listeners)
    error_message = "Listener ports must be unique."
  }

  validation {
    condition     = alltrue([for k, l in var.listeners : l.protocol == "HTTPS" ? try(length(l.certificate_id) > 0, false) : true])
    error_message = "HTTPS listeners require certificate_id."
  }

  validation {
    condition     = alltrue([for k, l in var.listeners : l.protocol == "HTTPS" || l.certificate_id == null])
    error_message = "certificate_id is only valid on HTTPS listeners."
  }
}

variable "rules" {
  type = map(object({
    listener     = string
    priority     = number
    hosts        = optional(list(string), [])
    paths        = optional(list(string), [])
    server_group = optional(string)
    fixed_response = optional(object({
      content      = string
      content_type = optional(string, "text/plain")
      http_code    = optional(string, "503")
    }))
  }))
  description = "Forwarding rules keyed by name. Each needs a host or path condition and exactly one action: server_group (forward) or fixed_response."
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for k, r in var.rules : can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", k))])
    error_message = "Rule keys must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }

  validation {
    condition     = alltrue([for k, r in var.rules : r.priority == floor(r.priority) && r.priority >= 1 && r.priority <= 10000])
    error_message = "Rule priority must be a whole number from 1 to 10000."
  }

  validation {
    condition     = alltrue([for k, r in var.rules : length(r.hosts) + length(r.paths) >= 1])
    error_message = "Each rule needs at least one host or path condition."
  }

  validation {
    condition     = alltrue([for k, r in var.rules : alltrue([for p in r.paths : startswith(p, "/")])])
    error_message = "Rule paths must start with '/'."
  }

  validation {
    condition     = alltrue([for k, r in var.rules : (r.server_group != null) != (r.fixed_response != null)])
    error_message = "Each rule needs exactly one of server_group or fixed_response."
  }

  validation {
    condition     = alltrue([for k, r in var.rules : r.fixed_response == null ? true : can(regex("^(2|4|5)[0-9]{2}$", r.fixed_response.http_code))])
    error_message = "fixed_response http_code must be a 2xx, 4xx or 5xx status code."
  }

  validation {
    condition     = length(distinct([for k, r in var.rules : "${r.listener}:${r.priority}"])) == length(var.rules)
    error_message = "Rule priorities must be unique per listener."
  }
}

variable "tags" {
  type        = map(string)
  description = "Resource tags. At least one tag is required. Rules are not taggable in the provider."
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
