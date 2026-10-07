variable "snat_table_id" {
  type        = string
  description = "SNAT table ID of the NAT gateway (nat module output snat_table_ids)."

  validation {
    condition     = can(regex("^stb-", var.snat_table_id))
    error_message = "snat_table_id must be a SNAT table ID (stb-...)."
  }
}

variable "snat_ips" {
  type        = list(string)
  description = "Public EIP addresses (internet NAT) or NAT IPs (private NAT) used as translated source."
  nullable    = false

  validation {
    condition     = length(var.snat_ips) >= 1
    error_message = "At least one snat_ip is required."
  }

  validation {
    condition     = alltrue([for ip in var.snat_ips : can(cidrnetmask("${ip}/32"))])
    error_message = "Every snat_ips item must be a valid IPv4 address."
  }

  validation {
    condition     = length(distinct(var.snat_ips)) == length(var.snat_ips)
    error_message = "snat_ips must not repeat an address."
  }
}

variable "entries" {
  type = list(object({
    name              = string
    source_cidr       = optional(string)
    source_vswitch_id = optional(string)
  }))
  description = "SNAT entries. Exactly one of source_cidr or source_vswitch_id per entry."
  nullable    = false

  validation {
    condition     = length(var.entries) >= 1
    error_message = "At least one SNAT entry is required."
  }

  validation {
    condition     = length(distinct([for e in var.entries : e.name])) == length(var.entries)
    error_message = "SNAT entry names must be unique."
  }

  validation {
    condition     = alltrue([for e in var.entries : can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", e.name))])
    error_message = "SNAT entry names must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }

  validation {
    condition     = alltrue([for e in var.entries : (e.source_cidr != null) != (e.source_vswitch_id != null)])
    error_message = "Each SNAT entry needs exactly one of source_cidr or source_vswitch_id."
  }

  validation {
    condition     = alltrue([for e in var.entries : e.source_cidr == null ? true : (can(cidrnetmask(e.source_cidr)) ? cidrhost(e.source_cidr, 0) == split("/", e.source_cidr)[0] : false)])
    error_message = "source_cidr must be an IPv4 CIDR with no host bits set."
  }

  validation {
    condition = (
      length(distinct([for e in var.entries : e.source_vswitch_id if e.source_vswitch_id != null])) == length([for e in var.entries : e.source_vswitch_id if e.source_vswitch_id != null]) &&
      length(distinct([for e in var.entries : e.source_cidr if e.source_cidr != null])) == length([for e in var.entries : e.source_cidr if e.source_cidr != null])
    )
    error_message = "Each source_vswitch_id and each source_cidr may appear in only one SNAT entry."
  }

  validation {
    condition     = alltrue([for e in var.entries : e.source_vswitch_id == null ? true : can(regex("^vsw-", e.source_vswitch_id))])
    error_message = "source_vswitch_id must be a vSwitch ID (vsw-...)."
  }
}

variable "tags" {
  type        = map(string)
  description = "Resource tags. At least one tag is required. Accepted for contract parity only: the provider resource is not taggable."
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
