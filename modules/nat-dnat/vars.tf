variable "forward_table_id" {
  type        = string
  description = "DNAT (forward) table ID of the NAT gateway (nat module output forward_table_ids)."

  validation {
    condition     = can(regex("^ftb-", var.forward_table_id))
    error_message = "forward_table_id must be a DNAT forward table ID (ftb-...)."
  }
}

variable "entries" {
  type = list(object({
    name          = string
    external_ip   = string
    external_port = string
    internal_ip   = string
    internal_port = string
    ip_protocol   = optional(string, "tcp")
    port_break    = optional(bool, false)
  }))
  description = "DNAT entries. Ports are a single port (\"80\"), a range (\"10/20\") or \"any\" when ip_protocol is any."
  nullable    = false

  validation {
    condition     = length(var.entries) >= 1
    error_message = "At least one DNAT entry is required."
  }

  validation {
    condition     = length(distinct([for e in var.entries : e.name])) == length(var.entries)
    error_message = "DNAT entry names must be unique."
  }

  validation {
    condition     = alltrue([for e in var.entries : can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", e.name))])
    error_message = "DNAT entry names must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }

  validation {
    condition     = alltrue([for e in var.entries : contains(["tcp", "udp", "any"], e.ip_protocol)])
    error_message = "ip_protocol must be tcp, udp or any."
  }

  validation {
    condition     = alltrue([for e in var.entries : can(cidrnetmask("${e.external_ip}/32")) && can(cidrnetmask("${e.internal_ip}/32"))])
    error_message = "external_ip and internal_ip must be valid IPv4 addresses."
  }

  validation {
    condition = alltrue([
      for e in var.entries : e.ip_protocol == "any" ? (e.external_port == "any" && e.internal_port == "any") : alltrue([
        for p in [e.external_port, e.internal_port] :
        can(regex("^[0-9]{1,5}(/[0-9]{1,5})?$", p)) ? alltrue([for x in split("/", p) : tonumber(x) >= 1 && tonumber(x) <= 65535]) : false
      ])
    ])
    error_message = "Ports must be 1-65535 (single port or 'first/last' range); with ip_protocol any both ports must be 'any'."
  }

  validation {
    condition = alltrue([
      for e in var.entries : (e.ip_protocol == "any" || !(can(regex("^[0-9]{1,5}(/[0-9]{1,5})?$", e.external_port)) && can(regex("^[0-9]{1,5}(/[0-9]{1,5})?$", e.internal_port)))) ? true : alltrue([
        for p in [e.external_port, e.internal_port] :
        length(split("/", p)) == 1 || tonumber(split("/", p)[0]) <= tonumber(split("/", p)[1])
      ])
    ])
    error_message = "A port range must have first <= last."
  }

  validation {
    condition = alltrue([
      for e in var.entries : (e.ip_protocol == "any" || !(can(regex("^[0-9]{1,5}(/[0-9]{1,5})?$", e.external_port)) && can(regex("^[0-9]{1,5}(/[0-9]{1,5})?$", e.internal_port)))) ? true : (
        (length(split("/", e.external_port)) == 1 ? 1 : tonumber(split("/", e.external_port)[1]) - tonumber(split("/", e.external_port)[0]) + 1) ==
        (length(split("/", e.internal_port)) == 1 ? 1 : tonumber(split("/", e.internal_port)[1]) - tonumber(split("/", e.internal_port)[0]) + 1)
      )
    ])
    error_message = "external_port and internal_port must cover the same number of ports."
  }

  validation {
    condition     = length(distinct([for e in var.entries : "${e.external_ip}:${e.external_port}:${e.ip_protocol}"])) == length(var.entries)
    error_message = "Each external_ip:external_port:ip_protocol may appear in only one DNAT entry."
  }

  # Overlap is judged per external_ip: an "any" mapping owns the whole address, tcp and udp ranges only collide within their own protocol.
  validation {
    condition = alltrue(flatten([
      for a in var.entries : [
        for b in var.entries :
        a.external_ip != b.external_ip || a.name == b.name ? true : (
          a.ip_protocol == "any" || b.ip_protocol == "any" ? false : (
            a.ip_protocol != b.ip_protocol ? true : (
              try(tonumber(split("/", a.external_port)[length(split("/", a.external_port)) - 1]) < tonumber(split("/", b.external_port)[0]) || tonumber(split("/", b.external_port)[length(split("/", b.external_port)) - 1]) < tonumber(split("/", a.external_port)[0]), true)
            )
          )
        )
      ]
    ]))
    error_message = "DNAT entries on one external_ip must not overlap in port range, and an any-protocol mapping cannot share its external_ip with another entry."
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
