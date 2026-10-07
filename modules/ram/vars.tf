variable "name" {
  type        = string
  description = "RAM user name, <component>-<instance>-c1-<tenant>-<env>."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{0,62}[a-z0-9]$", var.name))
    error_message = "name must be 2-64 chars: lowercase letters, digits, '.' and '-', starting and ending with a letter or digit."
  }
}

variable "comments" {
  type        = string
  description = "Optional RAM user comment."
  default     = null
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
