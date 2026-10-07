variable "cen_name" {
  type        = string
  description = "Name of the CEN instance and its transit router, <component>-<instance>-c1-<tenant>-<env>."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", var.cen_name))
    error_message = "cen_name must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }
}

variable "cen_id" {
  type        = string
  description = "Existing CEN to add this region's transit router to. Null creates the CEN instance in this stack."
  default     = null

  validation {
    condition     = var.cen_id == null ? true : can(regex("^cen-", var.cen_id))
    error_message = "cen_id must be a CEN ID (cen-...)."
  }
}

variable "description" {
  type        = string
  description = "Optional description for the CEN instance and the transit router."
  default     = null
}

variable "zones" {
  type        = list(string)
  description = "Registered availability zones; every zone_mappings zone_id must be one of them."
  nullable    = false

  validation {
    condition     = length(var.zones) >= 1
    error_message = "At least one availability zone must be registered."
  }
}

variable "vpc_attachments" {
  type = map(object({
    vpc_id = string
    zone_mappings = list(object({
      vswitch_id = string
      zone_id    = string
    }))
    description = optional(string)
  }))
  description = "VPC attachments keyed by attachment name. Each needs a vSwitch in at least two zones when more than one zone is registered; each is associated with and propagated to the system route table."
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for n, a in var.vpc_attachments : can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", n))])
    error_message = "Attachment names must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }

  validation {
    condition     = alltrue([for n, a in var.vpc_attachments : can(regex("^vpc-", a.vpc_id))])
    error_message = "vpc_id must be a VPC ID (vpc-...)."
  }

  validation {
    condition     = alltrue([for n, a in var.vpc_attachments : alltrue([for z in a.zone_mappings : can(regex("^vsw-", z.vswitch_id))])])
    error_message = "Every zone mapping needs a vswitch_id (vsw-...)."
  }

  validation {
    condition     = alltrue([for n, a in var.vpc_attachments : length(a.zone_mappings) >= 1 && length(a.zone_mappings) <= 10])
    error_message = "An attachment takes 1-10 zone mappings."
  }

  validation {
    condition     = alltrue([for n, a in var.vpc_attachments : alltrue([for z in a.zone_mappings : contains(var.zones, z.zone_id)])])
    error_message = "Every zone_id must be one of the registered zones."
  }

  validation {
    condition     = alltrue([for n, a in var.vpc_attachments : length(distinct([for z in a.zone_mappings : z.zone_id])) >= min(2, length(var.zones))])
    error_message = "With two or more registered zones an attachment needs vSwitches in at least two different zones."
  }
}

variable "peer_attachments" {
  type = map(object({
    peer_transit_router_id = string
    peer_region_id         = string
    bandwidth              = number
    link_type              = optional(string, "Gold")
  }))
  description = "Inter-region attachments to a transit router of the same CEN in another region, billed by data transfer. Keyed by attachment name; the peer region's leaf creates its own transit router."
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for n, a in var.peer_attachments : can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", n))])
    error_message = "Attachment names must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }

  validation {
    condition     = alltrue([for n, a in var.peer_attachments : can(regex("^tr-", a.peer_transit_router_id))])
    error_message = "peer_transit_router_id must be a transit router ID (tr-...)."
  }

  validation {
    condition     = alltrue([for n, a in var.peer_attachments : can(regex("^[a-z]{2}-[a-z0-9-]+$", a.peer_region_id))])
    error_message = "peer_region_id must be a valid Alibaba Cloud region ID, e.g. ap-southeast-5."
  }

  validation {
    condition     = alltrue([for n, a in var.peer_attachments : a.bandwidth > 0 && a.bandwidth == floor(a.bandwidth)])
    error_message = "bandwidth must be a positive integer (Mbit/s)."
  }

  validation {
    condition     = alltrue([for n, a in var.peer_attachments : contains(["Gold", "Platinum"], a.link_type)])
    error_message = "link_type must be Gold or Platinum."
  }
}

variable "remote_attachment_ids" {
  type        = map(string)
  description = "Peer attachments created by the other region's leaf (name => attachment ID); they are associated with and propagated to this transit router's system route table."
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for n, id in var.remote_attachment_ids : can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", n)) && length(id) > 0])
    error_message = "Remote attachment names must be 2-128 lowercase chars and IDs must not be empty."
  }

  validation {
    condition     = length(setintersection(toset(keys(var.remote_attachment_ids)), toset(concat(keys(var.vpc_attachments), keys(var.peer_attachments))))) == 0 && length(setintersection(toset(keys(var.vpc_attachments)), toset(keys(var.peer_attachments)))) == 0
    error_message = "Attachment names must be unique across vpc_attachments, peer_attachments and remote_attachment_ids."
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
