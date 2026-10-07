variable "name" {
  type        = string
  description = "Package name, <component>-<instance>-c1-<tenant>-<env>."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", var.name))
    error_message = "name must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }
}

variable "bandwidth" {
  type        = number
  description = "Shared bandwidth in Mbit/s, 1-1000."

  validation {
    condition     = var.bandwidth == floor(var.bandwidth) && var.bandwidth >= 1 && var.bandwidth <= 1000
    error_message = "bandwidth must be a whole number from 1 to 1000."
  }
}

variable "internet_charge_type" {
  type        = string
  description = "Billing method (ForceNew). Pay-by-traffic packages are limited to 5 per account and region."
  default     = "PayByBandwidth"
  nullable    = false

  validation {
    condition     = contains(["PayByBandwidth", "PayByTraffic"], var.internet_charge_type)
    error_message = "internet_charge_type must be PayByBandwidth or PayByTraffic."
  }
}

variable "isp" {
  type        = string
  description = "Line type (ForceNew). Must equal the ISP of every attached EIP. BGP_PRO exists only in some regions."
  default     = "BGP"
  nullable    = false

  validation {
    condition     = contains(["BGP", "BGP_PRO"], var.isp)
    error_message = "isp must be BGP or BGP_PRO."
  }
}

variable "description" {
  type        = string
  description = "Optional description, 2-256 characters."
  default     = null

  validation {
    condition     = var.description == null ? true : length(var.description) >= 2 && length(var.description) <= 256
    error_message = "description must be 2-256 characters."
  }
}

variable "deletion_protection" {
  type        = bool
  description = "Block deletion of the package."
  default     = true
  nullable    = false
}

variable "eip_ids" {
  type        = map(string)
  description = "EIPs to attach, name => allocation ID. The EIP must be PayAsYouGo, in this region, with the package ISP."
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for k, v in var.eip_ids : startswith(v, "eip-")])
    error_message = "eip_ids values must be EIP allocation IDs (eip-...)."
  }

  validation {
    condition     = length(var.eip_ids) <= 100
    error_message = "A package holds at most 100 EIPs by default."
  }
}

variable "alb_ids" {
  type        = map(string)
  description = "Internet-facing ALBs to attach, name => load balancer ID."
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for k, v in var.alb_ids : startswith(v, "alb-")])
    error_message = "alb_ids values must be ALB IDs (alb-...)."
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
