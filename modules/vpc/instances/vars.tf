variable "instances" {
  type        = any
  description = "VPCs to create, keyed by VPC name. Each value takes cidr_block (required), description, tags; any other key fails validation."

  validation {
    condition     = length(var.instances) >= 1
    error_message = "At least one VPC is required."
  }

  validation {
    condition = alltrue([
      for n, i in var.instances : can(keys(i)) ? alltrue([for k in keys(i) : contains(["cidr_block", "description", "tags"], k)]) : false
    ])
    error_message = "A VPC instance takes only cidr_block, description and tags."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every VPC. At least one tag is required."
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
