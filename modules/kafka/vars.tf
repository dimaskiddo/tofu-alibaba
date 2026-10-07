variable "name" {
  type        = string
  description = "Instance name, <component>-<instance>-c1-<tenant>-<env>."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,62}[a-z0-9]$", var.name))
    error_message = "name must be 3-64 chars: lowercase letters, digits and '-', starting with a letter and not ending with '-'."
  }
}

variable "partition_num" {
  type        = number
  description = "Total partitions the instance may hold across all topics."

  validation {
    condition     = var.partition_num == floor(var.partition_num) && var.partition_num >= 1
    error_message = "partition_num must be a whole number of at least 1."
  }
}

variable "disk_type" {
  type        = string
  description = "ssd or cloud_efficiency (ForceNew)."

  validation {
    condition     = contains(["ssd", "cloud_efficiency"], var.disk_type)
    error_message = "disk_type must be ssd or cloud_efficiency."
  }
}

variable "disk_size" {
  type        = number
  description = "Disk size in GB. It can only grow."

  validation {
    condition     = var.disk_size >= 500 && var.disk_size <= 6100 && var.disk_size % 100 == 0
    error_message = "disk_size must be 500-6100 GB in steps of 100."
  }
}

variable "io_max_spec" {
  type        = string
  description = "Traffic specification, e.g. alikafka.hw.2xlarge. Region specific."

  validation {
    condition     = trimspace(var.io_max_spec) != ""
    error_message = "io_max_spec must not be empty."
  }
}

variable "spec_type" {
  type        = string
  description = "Edition. The ACL needed for SASL users requires professional or professionalForHighRead."
  default     = "normal"
  nullable    = false

  validation {
    condition     = contains(["normal", "professional", "professionalForHighRead"], var.spec_type)
    error_message = "spec_type must be normal, professional or professionalForHighRead."
  }

  validation {
    condition     = length(var.sasl_users) == 0 || var.spec_type != "normal"
    error_message = "sasl_users enable the instance ACL, which needs spec_type professional or professionalForHighRead."
  }
}

variable "service_version" {
  type        = string
  description = "Kafka version."
  default     = "2.2.0"
  nullable    = false

  validation {
    condition     = contains(["2.2.0", "2.6.2"], var.service_version)
    error_message = "service_version must be 2.2.0 or 2.6.2."
  }
}

variable "placement" {
  type = list(object({
    zone_id    = string
    vswitch_id = string
  }))
  description = "Zone and vSwitch of the instance; two entries deploy it across two zones. The zone order is sent as selected_zones."
  nullable    = false

  validation {
    condition     = length(var.placement) >= 1 && length(var.placement) <= 2
    error_message = "placement needs one entry, or two for a multi-zone instance."
  }

  validation {
    condition     = length(distinct([for p in var.placement : p.zone_id])) == length(var.placement)
    error_message = "placement zones must be distinct."
  }

  validation {
    condition     = alltrue([for p in var.placement : p.zone_id != "" && can(regex("^vsw-", p.vswitch_id))])
    error_message = "Every placement needs a zone_id and a vSwitch ID (vsw-...)."
  }
}

variable "security_group_id" {
  type        = string
  description = "Security group of the instance. Null lets Alibaba Cloud create a default one."
  default     = null
}

variable "allowed_ips" {
  type        = list(string)
  description = "IPv4 CIDRs (a single address needs /32) allowed to reach the VPC endpoints (port 9092, and 9094 with sasl_users), at most 200. 0.0.0.0/0 is rejected."
  nullable    = false

  validation {
    condition     = length(var.allowed_ips) >= 1 && length(var.allowed_ips) <= 200
    error_message = "allowed_ips needs 1-200 entries."
  }

  validation {
    condition = alltrue([
      for ip in var.allowed_ips : can(regex("^((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])/(3[0-2]|[12]?[0-9])$", ip))
    ])
    error_message = "allowed_ips entries must be IPv4 CIDRs (use /32 for one address)."
  }

  validation {
    condition     = alltrue([for ip in var.allowed_ips : ip != "0.0.0.0" && !can(regex("/0$", ip))])
    error_message = "allowed_ips must not allow the whole internet (0.0.0.0/0)."
  }

  validation {
    condition     = length(distinct(var.allowed_ips)) == length(var.allowed_ips)
    error_message = "allowed_ips entries must be unique."
  }
}

variable "topics" {
  type = list(object({
    name          = string
    partition_num = optional(number, 12)
    remark        = optional(string)
    compact_topic = optional(bool, false)
    local_topic   = optional(bool, false)
  }))
  description = "Topics. remark defaults to the name with '.' replaced by '-'. compact_topic and local_topic are ForceNew."
  default     = []
  nullable    = false

  validation {
    condition     = length(distinct([for t in var.topics : t.name])) == length(var.topics)
    error_message = "Topic names must be unique."
  }

  validation {
    condition     = alltrue([for t in var.topics : can(regex("^[A-Za-z0-9._-]{3,64}$", t.name)) && !startswith(t.name, "__")])
    error_message = "Topic names must be 3-64 chars of letters, digits, '.', '_' and '-', and must not start with '__'."
  }

  validation {
    condition     = alltrue([for t in var.topics : t.partition_num == floor(t.partition_num) && t.partition_num >= 1 && t.partition_num <= 360])
    error_message = "Topic partition_num must be a whole number from 1 to 360."
  }

  validation {
    condition     = alltrue([for t in var.topics : !t.compact_topic || t.local_topic])
    error_message = "A compact_topic needs local_topic = true (compaction is available only on local storage)."
  }

  validation {
    condition     = alltrue([for t in var.topics : !t.local_topic || var.spec_type != "normal"])
    error_message = "local_topic needs spec_type professional or professionalForHighRead; the standard edition refuses local topics."
  }

  validation {
    condition     = alltrue([for t in var.topics : t.local_topic || t.partition_num >= 2])
    error_message = "Cloud-storage topics need partition_num of at least 2; only local topics may have 1."
  }

  validation {
    condition     = alltrue([for t in var.topics : can(regex("^[A-Za-z0-9_-]{3,64}$", coalesce(t.remark, replace(t.name, ".", "-"))))])
    error_message = "Topic remarks must be 3-64 chars of letters, digits, '_' and '-'."
  }
}

variable "consumer_groups" {
  type = list(object({
    name   = string
    remark = optional(string)
  }))
  description = "Consumer groups. remark defaults to the name with '.' replaced by '-'."
  default     = []
  nullable    = false

  validation {
    condition     = length(distinct([for g in var.consumer_groups : g.name])) == length(var.consumer_groups)
    error_message = "Consumer group names must be unique."
  }

  validation {
    condition     = alltrue([for g in var.consumer_groups : can(regex("^[A-Za-z0-9._-]{3,64}$", g.name))])
    error_message = "Consumer group names must be 3-64 chars of letters, digits, '.', '_' and '-'."
  }

  validation {
    condition     = alltrue([for g in var.consumer_groups : can(regex("^[A-Za-z0-9_-]{3,64}$", coalesce(g.remark, replace(g.name, ".", "-"))))])
    error_message = "Consumer group remarks must be 3-64 chars of letters, digits, '_' and '-'."
  }
}

variable "sasl_users" {
  type = list(object({
    name = string
    type = optional(string, "scram")
    acls = optional(list(object({
      resource_type = string
      resource_name = string
      pattern       = optional(string, "LITERAL")
      operation     = string
    })), [])
  }))
  description = "SASL users with their ACL entries. Any user turns the instance ACL on and opens the SASL port 9094 to allowed_ips."
  default     = []
  nullable    = false

  validation {
    condition     = length(distinct([for u in var.sasl_users : u.name])) == length(var.sasl_users)
    error_message = "SASL user names must be unique."
  }

  validation {
    condition     = alltrue([for u in var.sasl_users : can(regex("^[A-Za-z0-9_-]{1,64}$", u.name))])
    error_message = "SASL user names must be 1-64 chars of letters, digits, '_' and '-'."
  }

  validation {
    condition     = alltrue([for u in var.sasl_users : contains(["plain", "scram"], u.type)])
    error_message = "SASL user type must be plain or scram."
  }

  validation {
    condition     = alltrue(flatten([for u in var.sasl_users : [for a in u.acls : contains(["Topic", "Group", "Cluster", "TransactionalId"], a.resource_type)]]))
    error_message = "ACL resource_type must be Topic, Group, Cluster or TransactionalId."
  }

  validation {
    condition     = alltrue(flatten([for u in var.sasl_users : [for a in u.acls : contains(["LITERAL", "PREFIXED"], a.pattern)]]))
    error_message = "ACL pattern must be LITERAL or PREFIXED."
  }

  validation {
    condition     = alltrue(flatten([for u in var.sasl_users : [for a in u.acls : contains(["Write", "Read", "Describe", "IdempotentWrite"], a.operation)]]))
    error_message = "ACL operation must be Write, Read, Describe or IdempotentWrite."
  }

  validation {
    condition     = alltrue(flatten([for u in var.sasl_users : [for a in u.acls : trimspace(a.resource_name) != ""]]))
    error_message = "ACL resource_name must not be empty; use '*' for every resource."
  }

  validation {
    condition = alltrue(flatten([
      for u in var.sasl_users : [
        for i, a in u.acls : !contains([for b in slice(u.acls, 0, i) : "${b.resource_type}/${b.resource_name}/${b.pattern}/${b.operation}"], "${a.resource_type}/${a.resource_name}/${a.pattern}/${a.operation}")
      ]
    ]))
    error_message = "A user must not repeat an identical ACL entry."
  }
}

variable "sasl_passwords" {
  type        = map(string)
  description = "SASL passwords keyed by user name, supplied by the implementor (through the instances wrapper); never commit them. A user without an entry gets a random password (output generated_passwords)."
  default     = {}
  nullable    = false
  sensitive   = true

  validation {
    condition     = alltrue([for k in nonsensitive(keys(var.sasl_passwords)) : contains([for u in var.sasl_users : u.name], k)])
    error_message = "sasl_passwords has an entry for a user that is not in sasl_users."
  }

  validation {
    condition     = nonsensitive(alltrue([for k, p in var.sasl_passwords : can(regex("^[A-Za-z0-9_]{8,64}$", p))]))
    error_message = "Each SASL password must be 8-64 characters of letters, digits and '_'."
  }
}

variable "password_length" {
  type        = number
  description = "Length of generated SASL passwords (letters and digits)."
  default     = 16
  nullable    = false

  validation {
    condition     = var.password_length == floor(var.password_length) && var.password_length >= 8 && var.password_length <= 64
    error_message = "password_length must be a whole number from 8 to 64."
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
