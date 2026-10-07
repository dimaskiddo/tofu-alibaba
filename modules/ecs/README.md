# ecs

Creates PostPaid ECS instances keyed by name, with optional key pairs and separate data disks. Module `tags` are merged with per-instance tags (the instance wins on a clash) and applied to `tags`, `volume_tags`, every created key pair and every separate data disk. Each instance `zone_id` must be one of `zones`. Login per instance, first match wins: `key_name` (existing pair), `public_key` (imported as a pair named after the instance), `generate_key_pair` (Alibaba creates the pair; the private key is written once to `<private_key_dir>/<instance>.pem` and never stored in state), the sensitive `password`, else a random password.

Provider: `aliyun/alicloud ~> 1.293`, `hashicorp/random ~> 3.7`. OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `zones` | `list(string)` | yes | Registered availability zones, at least one; every instance `zone_id` must be one of them. |
| `password` | `string` | no | Default `null`, sensitive. Login password for instances without a key pair. Supplied by the implementor (the example reads `EXAMPLE_STAGE_ECS_PASSWORD`); never commit it. 8-30 letters and digits with at least one upper case, one lower case and one digit. Null means a random password per instance. |
| `private_key_dir` | `string` | no | Default `null`. Directory for generated private keys; required when an instance sets `generate_key_pair`. |
| `instances` | `map(object)` | yes | ECS instances keyed by instance name `<component>-<instance>-c1-<tenant>-<env>`; the key becomes the instance name. At least one entry. Key rule: 2-128 chars, lowercase letters, digits and `-`, starting with a letter and not ending with `-`. Fields in the table below. |
| `tags` | `map(string)` | yes | Resource tags. At least one tag is required; keys and values must not be empty. |

### `instances` fields

| Field | Type | Default | Rule |
|---|---|---|---|
| `instance_type` | `string` | required | Not empty. |
| `image_id` | `string` | required | Not empty. Changing it rebuilds the system disk in place (instance stopped, system-disk data lost; ID, private IP and data disks kept). |
| `zone_id` | `string` | required | Must be in `zones`. The instance zone follows its vSwitch, so a postcondition fails the apply when the vSwitch lies in another zone; data disks are placed in the instance's real zone. |
| `vswitch_id` | `string` | required | Must start with `vsw-`. |
| `security_group_ids` | `list(string)` | required | At least one, each starting with `sg-`. |
| `private_ip` | `string` | `null` | Valid IPv4 address; unique across all instances. |
| `key_name` | `string` | `null` | Existing key pair. |
| `public_key` | `string` | `null` | OpenSSH public key, must start with `ssh-`. |
| `generate_key_pair` | `bool` | `false` | Needs `private_key_dir`. |
| `password_length` | `number` | `8` | Whole number 8-30; length of the random password. |
| `host_name` | `string` | `null` | |
| `description` | `string` | `null` | |
| `user_data` | `string` | `null` | |
| `system_disk_category` | `string` | `"cloud_essd"` | `cloud_efficiency`, `cloud_ssd`, `cloud_essd`, `cloud`, `cloud_auto`, `cloud_essd_entry`. |
| `system_disk_size` | `number` | `40` | Whole GiB, 20-500. |
| `system_disk_performance_level` | `string` | `null` | `PL0`-`PL3`, only with `system_disk_category = "cloud_essd"`. Null keeps the provider default. |
| `system_disk_encrypted` | `bool` | `false` | |
| `system_disk_kms_key_id` | `string` | `null` | Requires `system_disk_encrypted = true`. |
| `internet_max_bw_out` | `number` | `0` | Whole Mbps, 0-100. 0 leaves the instance without a public IP. |
| `deletion_protection` | `bool` | `false` | |
| `data_disks` | `list(object)` | `[]` | Separate disks, fields below. |
| `tags` | `map(string)` | `{}` | Merged over the module `tags`; keys and values must not be empty. |

At most one of `key_name`, `public_key` and `generate_key_pair` per instance.

### `data_disks` fields

| Field | Type | Default | Rule |
|---|---|---|---|
| `name` | `string` | required | Lowercase letters, digits and `-`, starting with a letter; unique within the instance. `<instance>-<name>` becomes the disk name and must be at most 128 chars. |
| `size` | `number` | required | Whole GiB, at least 20. |
| `category` | `string` | `"cloud_essd"` | `cloud_efficiency`, `cloud_ssd`, `cloud_essd`, `cloud`, `cloud_auto`, `cloud_essd_entry`. |
| `performance_level` | `string` | `null` | `PL0`-`PL3`, only with `category = "cloud_essd"`. |
| `encrypted` | `bool` | `false` | |
| `kms_key_id` | `string` | `null` | Requires `encrypted = true`. |
| `resize_type` | `string` | `"online"` | `online` or `offline`. |

## Outputs

| Name | Description |
|---|---|
| `instance_ids` | Instance IDs keyed by instance name. |
| `private_ips` | Primary private IPs keyed by instance name. |
| `public_ips` | Public IPs keyed by instance name (empty when no public bandwidth is set). |
| `instance_by_name` | `id`, `private_ip` and `zone_id` (the instance's real `availability_zone`) keyed by instance name. |
| `data_disk_ids` | Data disk IDs keyed by `<instance>/<disk name>`. |
| `generated_passwords` | Sensitive. Random passwords keyed by instance name; instances with a key pair or a supplied `password` are absent. |

## Login behaviour

- Key pairs: Windows images do not support key pairs. Changing `key_name` or the password reboots a running instance.
- `generate_key_pair`: the private key exists only in the apply that creates it (`key_file` changes are ignored afterwards).
- Random password: stable in state after creation. Without `password`, every instance with no key field gets one; with `password`, none is generated and `generated_passwords` is empty.
- Billing: instances are `PostPaid`, data disks `PayAsYouGo`; neither is configurable.

## Disks and resizing

System disk: `system_disk_size` grows in place; `system_disk_performance_level` changes in place; changing `system_disk_category` replaces the instance.

Data disks are separate `alicloud_ecs_disk` + `alicloud_ecs_disk_attachment` resources keyed `<instance>/<disk name>` (the Alibaba disk name is `<instance>-<disk name>`, since `/` is not allowed), so the instance is never touched:
- Add an entry to attach a new disk; remove it to detach and delete that disk.
- `size` grows in place (`resize_type = "online"` by default, `"offline"` needs an instance restart). Alibaba does not shrink disks.
- `category` and `performance_level` change in place.
- Renaming a disk `name` replaces it and loses its data.
- Growing the filesystem inside the OS (`growpart`, `resize2fs`) stays with the operator.

Encryption: `system_disk_encrypted` / `system_disk_kms_key_id` and a data disk's `encrypted` / `kms_key_id` are all ForceNew. Enabling or changing them on an existing disk replaces it (the instance, for the system disk), so decide before the first apply. A key ID requires `encrypted = true`; without one, Alibaba Cloud's default service key is used. Disabling or deleting the KMS key locks the disks encrypted with it.

## Instances wrapper

None. This module already takes the `instances` map; a leaf uses `source = ".../modules//ecs"` directly.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
```
