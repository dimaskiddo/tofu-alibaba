variable "name" {
  type        = string
  description = "Key alias name, <component>-<instance>-c1-<tenant>-<env>. The alias becomes alias/<name>."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,239}$", var.name))
    error_message = "name must be 1-240 chars: lowercase letters, digits and '-', starting with a letter or digit."
  }
}

variable "dkms_instance_id" {
  type        = string
  description = "KMS instance the key is created in (ForceNew). The instance is bought outside this repository."

  validation {
    condition     = length(var.dkms_instance_id) > 0
    error_message = "dkms_instance_id must not be empty."
  }
}

variable "description" {
  type        = string
  description = "Optional key description."
  default     = null
}

variable "key_spec" {
  type        = string
  description = "Symmetric key spec (ForceNew)."
  default     = "Aliyun_AES_256"
  nullable    = false

  validation {
    condition     = contains(["Aliyun_AES_256", "Aliyun_AES_192", "Aliyun_AES_128", "Aliyun_SM4"], var.key_spec)
    error_message = "key_spec must be a symmetric spec: Aliyun_AES_256, Aliyun_AES_192, Aliyun_AES_128 or Aliyun_SM4."
  }
}

variable "rotation_interval" {
  type        = string
  description = "Automatic rotation period such as 365d, 8760h or 31536000s, between 7d and 365d. Null disables rotation."
  default     = "365d"

  validation {
    condition     = var.rotation_interval == null ? true : can(regex("^[1-9][0-9]*[dhms]$", var.rotation_interval))
    error_message = "rotation_interval must be a positive number plus d, h, m or s (for example 365d), or null."
  }

  validation {
    condition = var.rotation_interval == null ? true : try(
      tonumber(regex("^([1-9][0-9]*)[dhms]$", var.rotation_interval)[0]) * { d = 86400, h = 3600, m = 60, s = 1 }[substr(var.rotation_interval, -1, 1)] >= 604800 &&
      tonumber(regex("^([1-9][0-9]*)[dhms]$", var.rotation_interval)[0]) * { d = 86400, h = 3600, m = 60, s = 1 }[substr(var.rotation_interval, -1, 1)] <= 31536000,
      true
    )
    error_message = "rotation_interval must be between 7 days (604800s) and 365 days (31536000s)."
  }
}

variable "pending_window_in_days" {
  type        = number
  description = "Days a deleted key stays recoverable (7-366)."
  default     = 30
  nullable    = false

  validation {
    condition     = var.pending_window_in_days >= 7 && var.pending_window_in_days <= 366 && floor(var.pending_window_in_days) == var.pending_window_in_days
    error_message = "pending_window_in_days must be a whole number from 7 to 366."
  }
}

variable "deletion_protection" {
  type        = bool
  description = "Block deletion of the key. Deleting a key in use locks every disk and database encrypted with it."
  default     = true
  nullable    = false
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
