variable "instances" {
  type        = any
  description = "Instances keyed by the instance `name` value. Each value takes the inputs of ../; its optional tags merge over the shared tags."

  validation {
    condition     = length(var.instances) >= 1
    error_message = "At least one instance is required."
  }

  validation {
    condition     = alltrue([for n, i in var.instances : can(keys(i)) ? length(setsubtract(keys(i), ["route_table_id", "vpc_id", "route_table_name", "description", "vswitch_ids", "routes", "tags"])) == 0 : false])
    error_message = "An instance has an unknown key; allowed keys are the inputs of ../ except the name, i.e. route_table_id, vpc_id, route_table_name, description, vswitch_ids, routes, tags."
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
