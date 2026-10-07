variable "name" {
  type        = string
  description = "Security group name, <component>-<instance>-c1-<tenant>-<env>."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", var.name))
    error_message = "name must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC the security group belongs to."

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "vpc_id must be a VPC ID (vpc-...)."
  }
}

variable "description" {
  type        = string
  description = "Optional security group description."
  default     = null
}

variable "inner_access_policy" {
  type        = string
  description = "Intra-group traffic policy: Accept or Drop."
  default     = "Accept"
  nullable    = false

  validation {
    condition     = contains(["Accept", "Drop"], var.inner_access_policy)
    error_message = "inner_access_policy must be Accept or Drop."
  }
}

variable "rules" {
  type = list(object({
    name                     = string
    type                     = string
    ip_protocol              = string
    port_range               = optional(string, "-1/-1")
    cidr_ip                  = optional(string)
    source_security_group_id = optional(string)
    policy                   = optional(string, "accept")
    priority                 = optional(number, 1)
    description              = optional(string)
  }))
  description = "Rules keyed by unique name. Exactly one of cidr_ip or source_security_group_id per rule. tcp/udp need a 'first/last' port_range; other protocols use '-1/-1'."
  default     = []
  nullable    = false

  validation {
    condition     = length(distinct([for r in var.rules : r.name])) == length(var.rules)
    error_message = "Rule names must be unique."
  }

  validation {
    condition     = alltrue([for r in var.rules : can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", r.name))])
    error_message = "Rule names must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }

  validation {
    condition     = alltrue([for r in var.rules : contains(["ingress", "egress"], r.type)])
    error_message = "Rule type must be ingress or egress."
  }

  validation {
    condition     = alltrue([for r in var.rules : contains(["tcp", "udp", "icmp", "gre", "all"], r.ip_protocol)])
    error_message = "Rule ip_protocol must be one of tcp, udp, icmp, gre, all."
  }

  validation {
    condition     = alltrue([for r in var.rules : contains(["accept", "drop"], r.policy)])
    error_message = "Rule policy must be accept or drop."
  }

  validation {
    condition     = alltrue([for r in var.rules : r.priority == floor(r.priority) && r.priority >= 1 && r.priority <= 100])
    error_message = "Rule priority must be a whole number from 1 to 100."
  }

  validation {
    condition     = alltrue([for r in var.rules : (r.cidr_ip != null) != (r.source_security_group_id != null)])
    error_message = "Each rule needs exactly one of cidr_ip or source_security_group_id."
  }

  validation {
    condition     = alltrue([for r in var.rules : r.cidr_ip == null ? true : (can(cidrnetmask(r.cidr_ip)) ? cidrhost(r.cidr_ip, 0) == split("/", r.cidr_ip)[0] : false)])
    error_message = "Rule cidr_ip must be an IPv4 CIDR with no host bits set."
  }

  validation {
    condition     = alltrue([for r in var.rules : r.source_security_group_id == null ? true : can(regex("^sg-", r.source_security_group_id))])
    error_message = "Rule source_security_group_id must be a security group ID (sg-...)."
  }

  validation {
    condition = alltrue([
      for r in var.rules : contains(["tcp", "udp"], r.ip_protocol) ? (
        can(regex("^[0-9]{1,5}/[0-9]{1,5}$", r.port_range)) &&
        alltrue([for x in split("/", r.port_range) : tonumber(x) >= 1 && tonumber(x) <= 65535]) &&
        tonumber(split("/", r.port_range)[0]) <= tonumber(split("/", r.port_range)[1])
      ) : r.port_range == "-1/-1"
    ])
    error_message = "tcp/udp rules need port_range 'first/last' within 1-65535 (first <= last); other protocols must use '-1/-1'."
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
