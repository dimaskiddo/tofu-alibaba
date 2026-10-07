variable "zones" {
  type        = list(string)
  description = "Registered availability zones; every instance zone_id must be one of them."
  nullable    = false

  validation {
    condition     = length(var.zones) >= 1
    error_message = "At least one availability zone must be registered."
  }
}

variable "password" {
  type        = string
  description = "Login password for instances without a key pair. Supplied by the implementor; unset means a random password per instance (output generated_passwords)."
  default     = null
  sensitive   = true

  validation {
    condition     = var.password == null ? true : can(regex("^[A-Za-z0-9]{8,30}$", var.password)) && can(regex("[a-z]", var.password)) && can(regex("[A-Z]", var.password)) && can(regex("[0-9]", var.password))
    error_message = "password must be 8-30 alphanumeric chars with upper case, lower case and digits."
  }
}

variable "private_key_dir" {
  type        = string
  description = "Directory that receives <instance>.pem for instances with generate_key_pair. The key is written once, at creation."
  default     = null
}

variable "instances" {
  type = map(object({
    instance_type                 = string
    image_id                      = string
    zone_id                       = string
    vswitch_id                    = string
    security_group_ids            = list(string)
    private_ip                    = optional(string)
    key_name                      = optional(string)
    public_key                    = optional(string)
    generate_key_pair             = optional(bool, false)
    password_length               = optional(number, 8)
    host_name                     = optional(string)
    description                   = optional(string)
    user_data                     = optional(string)
    system_disk_category          = optional(string, "cloud_essd")
    system_disk_size              = optional(number, 40)
    system_disk_performance_level = optional(string)
    # ForceNew: changing either replaces the instance. A KMS key needs system_disk_encrypted = true.
    system_disk_encrypted  = optional(bool, false)
    system_disk_kms_key_id = optional(string)
    internet_max_bw_out    = optional(number, 0)
    deletion_protection    = optional(bool, false)
    data_disks = optional(list(object({
      name              = string
      size              = number
      category          = optional(string, "cloud_essd")
      performance_level = optional(string)
      encrypted         = optional(bool, false)
      kms_key_id        = optional(string)
      resize_type       = optional(string, "online")
    })), [])
    tags = optional(map(string), {})
  }))
  description = "ECS instances keyed by instance name (<component>-<instance>-c1-<tenant>-<env>)."
  nullable    = false

  validation {
    condition     = length(var.instances) >= 1
    error_message = "At least one instance is required."
  }

  validation {
    condition     = alltrue([for k, i in var.instances : can(regex("^[a-z][a-z0-9-]{0,126}[a-z0-9]$", k))])
    error_message = "Instance names must be 2-128 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }

  validation {
    condition     = alltrue([for k, i in var.instances : length([for v in [i.key_name != null, i.public_key != null, i.generate_key_pair] : v if v]) <= 1])
    error_message = "Set at most one of key_name, public_key and generate_key_pair per instance."
  }

  validation {
    condition     = alltrue([for k, i in var.instances : i.password_length == floor(i.password_length) && i.password_length >= 8 && i.password_length <= 30])
    error_message = "password_length must be a whole number from 8 to 30."
  }

  validation {
    condition     = alltrue([for k, i in var.instances : i.public_key == null ? true : can(regex("^ssh-", i.public_key))])
    error_message = "public_key must be an OpenSSH public key (ssh-rsa ...)."
  }

  validation {
    condition     = alltrue([for k, i in var.instances : can(regex("^vsw-", i.vswitch_id))])
    error_message = "Every instance needs a vswitch_id (vsw-...)."
  }

  validation {
    condition     = alltrue([for k, i in var.instances : length(i.security_group_ids) >= 1 && alltrue([for sg in i.security_group_ids : can(regex("^sg-", sg))])])
    error_message = "Every instance needs at least one security group ID (sg-...)."
  }

  validation {
    condition     = alltrue([for k, i in var.instances : i.private_ip == null ? true : can(cidrhost("${i.private_ip}/32", 0))])
    error_message = "private_ip must be a valid IPv4 address."
  }

  validation {
    condition     = alltrue([for k, i in var.instances : i.instance_type != "" && i.image_id != ""])
    error_message = "instance_type and image_id are required."
  }

  validation {
    condition     = alltrue([for k, i in var.instances : contains(["cloud_efficiency", "cloud_ssd", "cloud_essd", "cloud", "cloud_auto", "cloud_essd_entry"], i.system_disk_category)])
    error_message = "system_disk_category must be one of cloud_efficiency, cloud_ssd, cloud_essd, cloud, cloud_auto, cloud_essd_entry."
  }

  validation {
    condition     = alltrue([for k, i in var.instances : i.system_disk_size == floor(i.system_disk_size) && i.system_disk_size >= 20 && i.system_disk_size <= 500])
    error_message = "system_disk_size must be a whole number of GiB from 20 to 500."
  }

  validation {
    condition     = alltrue([for k, i in var.instances : i.internet_max_bw_out >= 0 && i.internet_max_bw_out <= 100 && i.internet_max_bw_out == floor(i.internet_max_bw_out)])
    error_message = "internet_max_bw_out must be a whole number of Mbps from 0 to 100."
  }

  validation {
    condition     = alltrue(flatten([for k, i in var.instances : [for d in i.data_disks : d.size >= 20 && d.size == floor(d.size)]]))
    error_message = "data disk size must be a whole number of GiB, at least 20."
  }

  validation {
    condition = alltrue(flatten([for k, i in var.instances : [
      for d in concat(
        [{ level = i.system_disk_performance_level, category = i.system_disk_category }],
        [for dd in i.data_disks : { level = dd.performance_level, category = dd.category }]
      ) : d.level == null ? true : contains(["PL0", "PL1", "PL2", "PL3"], d.level) && d.category == "cloud_essd"
    ]]))
    error_message = "performance_level must be PL0, PL1, PL2 or PL3 and only applies to category cloud_essd (system and data disks)."
  }

  validation {
    condition     = alltrue([for k, i in var.instances : i.system_disk_kms_key_id == null || i.system_disk_encrypted])
    error_message = "system_disk_kms_key_id requires system_disk_encrypted = true."
  }

  validation {
    condition     = alltrue(flatten([for k, i in var.instances : [for d in i.data_disks : d.kms_key_id == null || d.encrypted]]))
    error_message = "A data disk kms_key_id requires encrypted = true."
  }

  validation {
    condition     = alltrue(flatten([for k, i in var.instances : [for d in i.data_disks : contains(["cloud_efficiency", "cloud_ssd", "cloud_essd", "cloud", "cloud_auto", "cloud_essd_entry"], d.category)]]))
    error_message = "data disk category must be one of cloud_efficiency, cloud_ssd, cloud_essd, cloud, cloud_auto, cloud_essd_entry."
  }

  validation {
    condition     = alltrue(flatten([for k, i in var.instances : [for d in i.data_disks : contains(["online", "offline"], d.resize_type)]]))
    error_message = "data disk resize_type must be online or offline."
  }

  validation {
    condition     = alltrue(flatten([for k, i in var.instances : [for d in i.data_disks : can(regex("^[a-z][a-z0-9-]*$", d.name))]]))
    error_message = "data disk names must be lowercase letters, digits and '-', starting with a letter."
  }

  validation {
    condition     = alltrue(flatten([for k, i in var.instances : [for d in i.data_disks : length(k) + length(d.name) + 1 <= 128]]))
    error_message = "<instance>-<disk name> is the Alibaba disk name and must be at most 128 chars."
  }

  validation {
    condition     = alltrue([for k, i in var.instances : length(distinct([for d in i.data_disks : d.name])) == length(i.data_disks)])
    error_message = "Data disk names must be unique within an instance."
  }

  validation {
    condition     = alltrue(flatten([for k, i in var.instances : [for t, v in i.tags : length(t) > 0 && length(v) > 0]]))
    error_message = "Per-instance tag keys and values must not be empty."
  }

  validation {
    condition     = length(distinct([for k, i in var.instances : i.private_ip if i.private_ip != null])) == length([for k, i in var.instances : i.private_ip if i.private_ip != null])
    error_message = "private_ip values must be unique."
  }
}

variable "tags" {
  type        = map(string)
  description = "Resource tags applied to instances and their volumes. At least one tag is required."
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
