variable "instances" {
  type        = any
  description = "Instances keyed by resource name (the instance `name` value). Each value takes the inputs of ../ except name; its optional tags merge over the shared tags."

  validation {
    condition     = length(var.instances) >= 1
    error_message = "At least one instance is required."
  }

  validation {
    condition = alltrue([
      for n, i in var.instances : can(keys(i)) ? alltrue([for k in keys(i) : contains(["address_type", "vswitch_id", "master_zone_id", "slave_zone_id", "load_balancer_spec", "internet_charge_type", "bandwidth", "backend_servers", "listeners", "tags"], k)]) : false
    ])
    error_message = "Instance entries accept only address_type, vswitch_id, master_zone_id, slave_zone_id, load_balancer_spec, internet_charge_type, bandwidth, backend_servers, listeners and tags."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [for x in values(try(i.listeners, {})) : try(length(setsubtract(keys(x), ["protocol", "frontend_port", "backend_port", "scheduler", "bandwidth", "server_certificate_id"])) == 0, false)]]))
    error_message = "listeners entries: accepted keys are protocol, frontend_port, backend_port, scheduler, bandwidth, server_certificate_id."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [for x in values(try(i.backend_servers, {})) : try(length(setsubtract(keys(x), ["server_id", "port", "weight", "type"])) == 0, false)]]))
    error_message = "backend_servers entries: accepted keys are server_id, port, weight, type."
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
  description = "Tags applied to every instance. At least one tag is required."
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
