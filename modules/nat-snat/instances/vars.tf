variable "instances" {
  type        = any
  description = "Instances keyed by the instance `name` value. Each value takes the inputs of ../; its optional tags merge over the shared tags."

  validation {
    condition     = length(var.instances) >= 1
    error_message = "At least one instance is required."
  }

  validation {
    condition     = alltrue([for n, i in var.instances : can(keys(i)) ? length(setsubtract(keys(i), ["snat_table_id", "snat_ips", "entries", "tags"])) == 0 : false])
    error_message = "An instance has an unknown key; allowed keys are the inputs of ../ except the name, i.e. snat_table_id, snat_ips, entries, tags."
  }

  # The provider rejects a second entry for the same source on one SNAT table; catch it at plan time.
  validation {
    condition = (
      !alltrue([for n, i in var.instances : can(i.snat_table_id) && can(i.entries)]) ? true :
      length(distinct(flatten([for n, i in var.instances : [for e in i.entries : "${i.snat_table_id}/${try(e.source_vswitch_id, "")}/${try(e.source_cidr, "")}"]]))) == length(flatten([for n, i in var.instances : i.entries]))
    )
    error_message = "Two SNAT entries on the same snat_table_id must not share a source_vswitch_id or source_cidr."
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
