variable "instances" {
  type        = any
  description = "Instances keyed by resource name (the instance `name` value). Each value takes the inputs of ../ except name; its optional tags merge over the shared tags."

  validation {
    condition     = length(var.instances) >= 1
    error_message = "At least one instance is required."
  }

  validation {
    condition = alltrue([
      for n, i in var.instances : can(keys(i)) ? alltrue([for k in keys(i) : contains(["vpc_id", "address_type", "load_balancer_edition", "zone_mappings", "server_groups", "listeners", "rules", "tags"], k)]) : false
    ])
    error_message = "Instance entries accept only vpc_id, address_type, load_balancer_edition, zone_mappings, server_groups, listeners, rules and tags."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [for x in try(i.zone_mappings, []) : try(length(setsubtract(keys(x), ["zone_id", "vswitch_id"])) == 0, false)]]))
    error_message = "zone_mappings entries: accepted keys are zone_id, vswitch_id."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [for x in values(try(i.server_groups, {})) : try(length(setsubtract(keys(x), ["protocol", "scheduler", "sticky", "health_check", "servers"])) == 0, false)]]))
    error_message = "server_groups entries: accepted keys are protocol, scheduler, sticky, health_check, servers."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [for x in values(try(i.server_groups, {})) : try(length(setsubtract(keys(x.health_check), ["enabled", "protocol", "path", "codes", "port"])) == 0, true)]]))
    error_message = "server_groups health_check: accepted keys are enabled, protocol, path, codes, port."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : flatten([for x in values(try(i.server_groups, {})) : [for y in try(x.servers, []) : try(length(setsubtract(keys(y), ["server_id", "server_type", "port", "weight"])) == 0, false)]])]))
    error_message = "server_groups servers: accepted keys are server_id, server_type, port, weight."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [for x in values(try(i.listeners, {})) : try(length(setsubtract(keys(x), ["protocol", "port", "default_server_group", "certificate_id", "description"])) == 0, false)]]))
    error_message = "listeners entries: accepted keys are protocol, port, default_server_group, certificate_id, description."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [for x in values(coalesce(try(i.rules, null), {})) : try(length(setsubtract(keys(x), ["listener", "priority", "hosts", "paths", "server_group", "fixed_response"])) == 0, false)]]))
    error_message = "rules entries: accepted keys are listener, priority, hosts, paths, server_group, fixed_response."
  }

  validation {
    condition     = alltrue(flatten([for n, i in var.instances : [for x in values(coalesce(try(i.rules, null), {})) : try(length(setsubtract(keys(x.fixed_response), ["content", "content_type", "http_code"])) == 0, true)]]))
    error_message = "rules fixed_response: accepted keys are content, content_type, http_code."
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
