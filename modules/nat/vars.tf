variable "nat_name" {
  type        = string
  description = "NAT gateway name, <component>-<instance>-c1-<tenant>-<env>."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", var.nat_name))
    error_message = "nat_name must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }
}

variable "network_type" {
  type        = string
  description = "internet = public NAT gateway, intranet = private (VPC) NAT gateway."
  default     = "internet"
  nullable    = false

  validation {
    condition     = contains(["internet", "intranet"], var.network_type)
    error_message = "network_type must be internet or intranet."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC the NAT gateway belongs to."

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "vpc_id must be a VPC ID (vpc-...)."
  }
}

variable "vpc_cidr_block" {
  type        = string
  description = "VPC CIDR; a private NAT IP CIDR must not overlap it. Required for intranet."
  default     = null

  validation {
    condition     = var.vpc_cidr_block == null ? true : (can(cidrnetmask(var.vpc_cidr_block)) ? cidrhost(var.vpc_cidr_block, 0) == split("/", var.vpc_cidr_block)[0] : false)
    error_message = "vpc_cidr_block must be an IPv4 CIDR with no host bits set."
  }

  validation {
    condition     = var.network_type == "intranet" ? var.vpc_cidr_block != null : true
    error_message = "vpc_cidr_block is required for intranet NAT gateways so the NAT IP CIDR overlap can be checked."
  }
}

variable "vswitch_id" {
  type        = string
  description = "vSwitch hosting the enhanced NAT gateway."

  validation {
    condition     = can(regex("^vsw-", var.vswitch_id))
    error_message = "vswitch_id must be a vSwitch ID (vsw-...)."
  }
}

variable "description" {
  type        = string
  description = "Optional NAT gateway description."
  default     = null
}

variable "eip_allocation_ids" {
  type        = map(string)
  description = "EIP allocation IDs keyed by EIP name, associated to an internet NAT gateway. Must be empty for intranet."
  default     = {}
  nullable    = false

  validation {
    condition     = var.network_type == "internet" ? length(var.eip_allocation_ids) >= 1 : true
    error_message = "An internet NAT gateway requires at least one EIP allocation ID."
  }

  validation {
    condition     = var.network_type == "intranet" ? length(var.eip_allocation_ids) == 0 : true
    error_message = "A private (intranet) NAT gateway cannot be associated with EIPs."
  }

  validation {
    condition     = alltrue([for k, v in var.eip_allocation_ids : can(regex("^eip-", v))])
    error_message = "eip_allocation_ids values must be EIP allocation IDs (eip-...)."
  }
}

variable "nat_ip_cidr" {
  type        = string
  description = "Private NAT IP CIDR. Required for intranet, must be empty for internet."
  default     = null

  validation {
    condition     = var.network_type == "intranet" ? var.nat_ip_cidr != null : var.nat_ip_cidr == null
    error_message = "nat_ip_cidr is required for intranet NAT gateways and must be unset for internet ones."
  }

  validation {
    condition = var.nat_ip_cidr == null ? true : (
      can(cidrnetmask(var.nat_ip_cidr)) ? (
        cidrhost(var.nat_ip_cidr, 0) == split("/", var.nat_ip_cidr)[0] &&
        anytrue([for p in ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"] : cidrcontains(p, var.nat_ip_cidr)]) &&
        tonumber(split("/", var.nat_ip_cidr)[1]) >= 16
      ) : false
    )
    error_message = "nat_ip_cidr must be an IPv4 CIDR with no host bits set, inside 10.0.0.0/8, 172.16.0.0/12 or 192.168.0.0/16, with a mask length of 16-32."
  }

  validation {
    condition = (var.nat_ip_cidr == null || var.vpc_cidr_block == null || !can(cidrcontains(var.vpc_cidr_block, var.nat_ip_cidr))) ? true : (
      !(cidrcontains(var.vpc_cidr_block, var.nat_ip_cidr) || cidrcontains(var.nat_ip_cidr, var.vpc_cidr_block))
    )
    error_message = "nat_ip_cidr must not overlap vpc_cidr_block."
  }
}

variable "nat_ips" {
  type        = map(object({ ip = optional(string) }))
  description = "Private NAT IPs (transit IPs) keyed by name, taken from nat_ip_cidr. ip pins the address (ForceNew); null lets Alibaba Cloud pick. Required for intranet, must be empty for internet."
  default     = {}
  nullable    = false

  validation {
    condition     = var.network_type == "intranet" ? length(var.nat_ips) >= 1 : length(var.nat_ips) == 0
    error_message = "An intranet NAT gateway needs at least one nat_ips entry; an internet one cannot have any."
  }

  validation {
    condition     = alltrue([for k, v in var.nat_ips : can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", k))])
    error_message = "nat_ips keys must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }

  validation {
    condition = var.nat_ip_cidr == null ? true : alltrue([
      for k, v in var.nat_ips : v.ip == null ? true : (can(cidrnetmask("${v.ip}/32")) ? (can(cidrcontains(var.nat_ip_cidr, v.ip)) ? cidrcontains(var.nat_ip_cidr, v.ip) : false) : false)
    ])
    error_message = "Every nat_ips ip must be a valid IPv4 address inside nat_ip_cidr."
  }

  validation {
    condition     = length(distinct([for k, v in var.nat_ips : v.ip if v.ip != null])) == length([for k, v in var.nat_ips : v.ip if v.ip != null])
    error_message = "Pinned nat_ips addresses must be distinct."
  }
}

variable "route_table_id" {
  type        = string
  description = "System route table of the NAT gateway VPC; gets nat_ip_cidr routed to the gateway. Required for intranet, must be unset for internet."
  default     = null

  validation {
    condition     = var.network_type == "intranet" ? var.route_table_id != null : var.route_table_id == null
    error_message = "route_table_id is required for intranet NAT gateways and must be unset for internet ones."
  }

  validation {
    condition     = var.route_table_id == null ? true : can(regex("^vtb-", var.route_table_id))
    error_message = "route_table_id must be a route table ID (vtb-...)."
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
