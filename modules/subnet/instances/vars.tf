variable "groups" {
  type        = any
  description = "Subnets per VPC, keyed by VPC name (the group folder). Each value takes vpc_id, vpc_cidr_block, subnets (name, cidr_block, zone_id, tags); any other key fails validation."

  validation {
    condition     = length(var.groups) >= 1
    error_message = "At least one VPC group is required."
  }

  validation {
    condition = alltrue([
      for n, g in var.groups : can(keys(g)) ? alltrue([for k in keys(g) : contains(["vpc_id", "vpc_cidr_block", "subnets"], k)]) : false
    ])
    error_message = "A VPC group takes only vpc_id, vpc_cidr_block and subnets."
  }

  validation {
    condition = alltrue(flatten([
      for n, g in var.groups : [for s in try(g.subnets, []) : try(length(setsubtract(keys(s), ["name", "cidr_block", "zone_id", "tags"])) == 0, false)]
    ]))
    error_message = "A subnet takes only name, cidr_block, zone_id and tags."
  }

  validation {
    condition     = length(distinct(flatten([for g in var.groups : [for s in try(g.subnets, []) : try(s.name, "")]]))) == length(flatten([for g in var.groups : [for s in try(g.subnets, []) : try(s.name, "")]]))
    error_message = "Subnet names must be unique across all VPC groups."
  }
}

variable "zones" {
  type        = list(string)
  description = "Registered availability zones."
  nullable    = false

  validation {
    condition     = length(var.zones) >= 1
    error_message = "At least one availability zone must be registered."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every vSwitch. At least one tag is required."
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
