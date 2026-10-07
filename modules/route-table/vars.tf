variable "route_table_id" {
  type        = string
  description = "Existing route table (for example the VPC system table) to add routes to. Null creates a custom route table instead."
  default     = null

  validation {
    condition     = var.route_table_id == null ? true : can(regex("^vtb-", var.route_table_id))
    error_message = "route_table_id must be a route table ID (vtb-...)."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC of the custom route table. Required when creating one, must be unset otherwise."
  default     = null

  validation {
    condition     = var.route_table_id == null ? (var.vpc_id != null && can(regex("^vpc-", var.vpc_id))) : var.vpc_id == null
    error_message = "vpc_id (vpc-...) is required to create a route table and must be unset when route_table_id is given."
  }
}

variable "route_table_name" {
  type        = string
  description = "Custom route table name, <component>-<instance>-c1-<tenant>-<env>. Required when creating one, must be unset otherwise."
  default     = null

  validation {
    condition = var.route_table_id == null ? (
      var.route_table_name != null && can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", coalesce(var.route_table_name, "-")))
    ) : var.route_table_name == null
    error_message = "route_table_name (2-128 chars: lowercase letters, digits and '-') is required to create a route table and must be unset when route_table_id is given."
  }
}

variable "description" {
  type        = string
  description = "Optional custom route table description. Must be unset when route_table_id is given."
  default     = null

  validation {
    condition     = var.route_table_id == null ? true : var.description == null
    error_message = "description cannot be set on an existing route table; it only applies to a custom one."
  }
}

variable "vswitch_ids" {
  type        = map(string)
  description = "vSwitches to bind to the custom route table, keyed by name. Only valid when creating a route table."
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for k, v in var.vswitch_ids : can(regex("^vsw-", v))])
    error_message = "vswitch_ids values must be vSwitch IDs (vsw-...)."
  }

  validation {
    condition     = var.route_table_id == null ? true : length(var.vswitch_ids) == 0
    error_message = "vswitch_ids cannot be set on an existing route table; bind vSwitches where the table is created."
  }
}

variable "routes" {
  type = map(object({
    destination_cidrblock = string
    nexthop_type          = string
    nexthop_id            = string
    description           = optional(string)
  }))
  description = "Custom routes keyed by route name. A destination must not equal or sit inside a vSwitch CIDR of the VPC."
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for k, r in var.routes : can(cidrnetmask(r.destination_cidrblock)) ? cidrhost(r.destination_cidrblock, 0) == split("/", r.destination_cidrblock)[0] : false])
    error_message = "Every route destination_cidrblock must be an IPv4 CIDR with no host bits set."
  }

  validation {
    condition     = alltrue([for k, r in var.routes : can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", k))])
    error_message = "Route keys must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }

  validation {
    condition = alltrue([for k, r in var.routes : contains([
      "Instance", "HaVip", "RouterInterface", "NetworkInterface", "VpnGateway", "IPv6Gateway",
      "NatGateway", "Attachment", "VpcPeer", "Ipv4Gateway", "GatewayEndpoint", "Ecr",
    ], r.nexthop_type)])
    error_message = "Every route nexthop_type must be one of the types supported by alicloud_route_entry."
  }

  validation {
    condition     = alltrue([for k, r in var.routes : length(r.nexthop_id) > 0])
    error_message = "Every route needs a nexthop_id."
  }

  validation {
    condition     = length(distinct([for k, r in var.routes : r.destination_cidrblock])) == length(var.routes)
    error_message = "Route destinations must be unique within a route table."
  }

  validation {
    condition     = var.route_table_id == null ? true : length(var.routes) >= 1
    error_message = "Adding to an existing route table needs at least one route."
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
