variable "eips" {
  type = list(object({
    name                 = string
    bandwidth            = optional(number, 5)
    internet_charge_type = optional(string, "PayByTraffic")
    isp                  = optional(string, "BGP")
    description          = optional(string)
    instance_id          = optional(string)
    tags                 = optional(map(string), {})
  }))
  description = "EIPs to create. Member tags merge over the shared tags for that EIP only. instance_id optionally associates the EIP (ECS instance, ENI eni-..., HAVIP havip-...); NAT association is done by the nat module."
  nullable    = false

  validation {
    condition     = length(var.eips) >= 1
    error_message = "At least one EIP is required."
  }

  validation {
    condition     = length(distinct([for e in var.eips : e.name])) == length(var.eips)
    error_message = "EIP names must be unique."
  }

  validation {
    condition     = alltrue([for e in var.eips : can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", e.name))])
    error_message = "EIP names must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }

  validation {
    condition     = alltrue([for e in var.eips : e.internet_charge_type == "PayByTraffic"])
    error_message = "internet_charge_type must be PayByTraffic: EIPs are pay-as-you-go, and international accounts only sell pay-as-you-go with PayByTraffic (PayByBandwidth needs a subscription, which is not supported)."
  }

  validation {
    condition     = alltrue([for e in var.eips : contains(["BGP", "BGP_PRO"], e.isp)])
    error_message = "isp must be BGP or BGP_PRO."
  }

  validation {
    condition = alltrue([
      for e in var.eips :
      e.bandwidth == floor(e.bandwidth) && e.bandwidth >= 1 && e.bandwidth <= 200
    ])
    error_message = "bandwidth must be a whole number of Mbit/s from 1 to 200."
  }

  validation {
    condition     = alltrue(flatten([for e in var.eips : [for k, v in e.tags : length(k) > 0 && length(v) > 0]]))
    error_message = "Per-EIP tag keys and values must not be empty."
  }

  validation {
    condition     = alltrue([for e in var.eips : e.instance_id == null || try(length(e.instance_id) > 0, false)])
    error_message = "instance_id must be non-empty when set."
  }

  validation {
    condition     = alltrue([for e in var.eips : e.instance_id == null || !startswith(coalesce(e.instance_id, "-"), "ngw-")])
    error_message = "instance_id must not be a NAT gateway (ngw-...); the nat module associates EIPs to NAT gateways."
  }

  validation {
    condition     = alltrue([for e in var.eips : e.instance_id == null || can(regex("^(i|eni|havip)-", coalesce(e.instance_id, "-")))])
    error_message = "instance_id must be an ECS instance (i-...), ENI (eni-...) or HAVIP (havip-...) ID."
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
