variable "instances" {
  type        = any
  description = "Instances keyed by resource name (the instance `name` value, used as the CEN and transit router name). Each value takes the inputs of ../ except cen_name; its optional tags merge over the shared tags."

  validation {
    condition     = length(var.instances) >= 1
    error_message = "At least one instance is required."
  }

  validation {
    condition     = alltrue([for n, i in var.instances : can(keys(i)) ? length(setsubtract(keys(i), ["cen_id", "description", "vpc_attachments", "peer_attachments", "remote_attachment_ids", "tags"])) == 0 : false])
    error_message = "An instance has an unknown key; allowed keys are the inputs of ../ except cen_name and zones, i.e. cen_id, description, vpc_attachments, peer_attachments, remote_attachment_ids, tags."
  }

  validation {
    condition     = alltrue([for n, i in var.instances : alltrue([for a in values(try(i.vpc_attachments, {})) : try(length(setsubtract(keys(a), ["vpc_id", "zone_mappings", "description"])) == 0, false)])])
    error_message = "A vpc_attachments entry has an unknown key; allowed keys are vpc_id, zone_mappings, description."
  }

  validation {
    condition     = alltrue([for n, i in var.instances : alltrue([for a in values(try(i.peer_attachments, {})) : try(length(setsubtract(keys(a), ["peer_transit_router_id", "peer_region_id", "bandwidth", "link_type"])) == 0, false)])])
    error_message = "A peer_attachments entry has an unknown key; allowed keys are peer_transit_router_id, peer_region_id, bandwidth, link_type."
  }

  validation {
    condition = (
      length(distinct(flatten([for n, i in var.instances : concat(keys(try(i.vpc_attachments, {})), keys(try(i.peer_attachments, {})))]))) ==
      length(flatten([for n, i in var.instances : concat(keys(try(i.vpc_attachments, {})), keys(try(i.peer_attachments, {})))]))
    )
    error_message = "Attachment names must be unique across all instances."
  }
}

variable "zones" {
  type        = list(string)
  description = "Registered availability zones, shared by every instance."
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
