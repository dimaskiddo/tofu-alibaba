variable "vpc_id" {
  type        = string
  description = "Parent VPC ID."

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "vpc_id must be a VPC ID (vpc-...)."
  }
}

variable "vpc_cidr_block" {
  type        = string
  description = "Parent VPC CIDR; every subnet must fall inside it."

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr_block)) ? cidrhost(var.vpc_cidr_block, 0) == split("/", var.vpc_cidr_block)[0] : false
    error_message = "vpc_cidr_block must be an IPv4 CIDR with no host bits set."
  }
}

variable "zones" {
  type        = list(string)
  description = "Registered availability zones; every subnet zone_id must be one of them."
  nullable    = false

  validation {
    condition     = length(var.zones) >= 1
    error_message = "At least one availability zone must be registered."
  }
}

variable "subnets" {
  type = list(object({
    name       = string
    cidr_block = string
    zone_id    = string
    tags       = optional(map(string), {})
  }))
  description = "vSwitches to create. Member tags merge over the shared tags for that vSwitch only."
  nullable    = false

  validation {
    condition     = length(var.subnets) >= 1
    error_message = "At least one subnet is required."
  }

  validation {
    condition     = length(distinct([for s in var.subnets : s.name])) == length(var.subnets)
    error_message = "Subnet names must be unique."
  }

  validation {
    condition     = alltrue([for s in var.subnets : can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", s.name))])
    error_message = "Subnet names must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }

  validation {
    condition     = alltrue([for s in var.subnets : can(cidrnetmask(s.cidr_block)) ? cidrhost(s.cidr_block, 0) == split("/", s.cidr_block)[0] : false])
    error_message = "Every subnet cidr_block must be an IPv4 CIDR with no host bits set."
  }

  validation {
    condition     = alltrue([for s in var.subnets : can(cidrnetmask(s.cidr_block)) ? tonumber(split("/", s.cidr_block)[1]) >= 16 && tonumber(split("/", s.cidr_block)[1]) <= 29 : false])
    error_message = "Every subnet cidr_block mask must be /16 to /29 (CreateVSwitch)."
  }

  validation {
    condition     = alltrue([for s in var.subnets : s.zone_id != ""])
    error_message = "zone_id is required for every subnet."
  }

  validation {
    condition     = alltrue([for s in var.subnets : contains(var.zones, s.zone_id)])
    error_message = "Every subnet zone_id must be one of the registered zones."
  }

  validation {
    condition     = alltrue([for z in var.zones : contains([for s in var.subnets : s.zone_id], z)])
    error_message = "Every registered zone must host at least one subnet."
  }

  validation {
    condition     = alltrue(flatten([for s in var.subnets : [for k, v in s.tags : length(k) > 0 && length(v) > 0]]))
    error_message = "Per-subnet tag keys and values must not be empty."
  }

  validation {
    condition = alltrue([
      for s in var.subnets :
      can(cidrcontains(var.vpc_cidr_block, s.cidr_block)) ? cidrcontains(var.vpc_cidr_block, s.cidr_block) : true
    ])
    error_message = "Every subnet cidr_block must be inside vpc_cidr_block."
  }

  validation {
    condition = alltrue(flatten([
      for i, a in var.subnets : [
        for j, b in var.subnets :
        can(cidrcontains(a.cidr_block, b.cidr_block)) ? !(cidrcontains(a.cidr_block, b.cidr_block) || cidrcontains(b.cidr_block, a.cidr_block)) : true
        if i < j
      ]
    ]))
    error_message = "Subnet CIDR blocks must not overlap."
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
