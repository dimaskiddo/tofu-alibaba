variable "peer_name" {
  type        = string
  description = "Peering connection name, <component>-<instance>-c1-<tenant>-<env>."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,113}[a-z0-9]$", var.peer_name))
    error_message = "peer_name must be 2-115 chars (the route names add a suffix of up to 13 chars): lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }
}

variable "vpc_id" {
  type        = string
  description = "Requester VPC ID."

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "vpc_id must be a VPC ID (vpc-...)."
  }
}

variable "vpc_cidr_block" {
  type        = string
  description = "Requester VPC CIDR; used to reject overlap with the accepter VPC."

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr_block)) ? cidrhost(var.vpc_cidr_block, 0) == split("/", var.vpc_cidr_block)[0] : false
    error_message = "vpc_cidr_block must be an IPv4 CIDR with no host bits set."
  }
}

variable "accepting_vpc_id" {
  type        = string
  description = "Accepter VPC ID."

  validation {
    condition     = can(regex("^vpc-", var.accepting_vpc_id))
    error_message = "accepting_vpc_id must be a VPC ID (vpc-...)."
  }

  validation {
    condition     = var.accepting_vpc_id != var.vpc_id
    error_message = "A VPC cannot peer with itself."
  }
}

variable "accepting_vpc_cidr_block" {
  type        = string
  description = "Accepter VPC CIDR; must not overlap vpc_cidr_block."

  validation {
    condition     = can(cidrnetmask(var.accepting_vpc_cidr_block)) ? cidrhost(var.accepting_vpc_cidr_block, 0) == split("/", var.accepting_vpc_cidr_block)[0] : false
    error_message = "accepting_vpc_cidr_block must be an IPv4 CIDR with no host bits set."
  }

  validation {
    condition = !can(cidrcontains(var.vpc_cidr_block, var.accepting_vpc_cidr_block)) ? true : (
      !(cidrcontains(var.vpc_cidr_block, var.accepting_vpc_cidr_block) || cidrcontains(var.accepting_vpc_cidr_block, var.vpc_cidr_block))
    )
    error_message = "The CIDR blocks of the two peered VPCs must not overlap."
  }
}

variable "accepting_region_id" {
  type        = string
  description = "Accepter VPC region; the requester region for intra-region, another region for inter-region."

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z0-9-]+$", var.accepting_region_id))
    error_message = "accepting_region_id must be a valid Alibaba Cloud region ID, e.g. ap-southeast-5."
  }
}

variable "accepting_ali_uid" {
  type        = number
  description = "Alibaba Cloud account ID owning the accepter VPC. Null keeps the peering inside the current account; a cross-account peering needs an accepter outside this module, and neither route table may be set for it."
  default     = null

  validation {
    condition     = var.accepting_ali_uid == null ? true : (var.accepting_ali_uid > 0 && var.accepting_ali_uid == floor(var.accepting_ali_uid))
    error_message = "accepting_ali_uid must be a positive integer."
  }
}

variable "bandwidth" {
  type        = number
  description = "Bandwidth in Mbit/s. Inter-region peering only; the API rejects it otherwise."
  default     = null

  validation {
    condition     = var.bandwidth == null ? true : (var.bandwidth > 0 && var.bandwidth == floor(var.bandwidth))
    error_message = "bandwidth must be a positive integer (Mbit/s)."
  }
}

variable "link_type" {
  type        = string
  description = "Link type, Gold or Platinum. Inter-region peering only; the API rejects it otherwise."
  default     = null

  validation {
    condition     = var.link_type == null ? true : contains(["Gold", "Platinum"], var.link_type)
    error_message = "link_type must be Gold or Platinum."
  }
}

variable "route_table_id" {
  type        = string
  description = "Requester route table that gets a route to the accepter CIDR via this peering. Null adds no route."
  default     = null

  validation {
    condition     = var.route_table_id == null ? true : can(regex("^vtb-", var.route_table_id))
    error_message = "route_table_id must be a route table ID (vtb-...)."
  }
}

variable "accepting_route_table_id" {
  type        = string
  description = "Accepter route table that gets a route to the requester CIDR via this peering. Null adds no route; must be null for an inter-region peering (checked against the provider region), since the provider is single-region."
  default     = null

  validation {
    condition     = var.accepting_route_table_id == null ? true : can(regex("^vtb-", var.accepting_route_table_id))
    error_message = "accepting_route_table_id must be a route table ID (vtb-...)."
  }
}

variable "description" {
  type        = string
  description = "Optional peering description."
  default     = null
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
