variable "vpc_name" {
  type        = string
  description = "VPC name, <component>-<instance>-c1-<tenant>-<env>."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", var.vpc_name))
    error_message = "vpc_name must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }
}

variable "cidr_block" {
  type        = string
  description = "VPC IPv4 CIDR block."

  validation {
    condition     = can(cidrnetmask(var.cidr_block)) ? cidrhost(var.cidr_block, 0) == split("/", var.cidr_block)[0] : false
    error_message = "cidr_block must be an IPv4 CIDR with no host bits set, e.g. 10.0.0.0/16."
  }

  validation {
    condition     = can(cidrnetmask(var.cidr_block)) ? tonumber(split("/", var.cidr_block)[1]) >= 16 && tonumber(split("/", var.cidr_block)[1]) <= 28 : false
    error_message = "cidr_block mask must be /16 to /28 (CreateVpc)."
  }
}

variable "description" {
  type        = string
  description = "Optional VPC description."
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
