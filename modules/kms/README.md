# kms

Creates one KMS key and its alias `alias/<name>` inside an existing KMS instance.

Provider: `aliyun/alicloud ~> 1.293`. OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | yes | Alias name without `alias/`, `<component>-<instance>-c1-<tenant>-<env>`. Must match `^[a-z0-9][a-z0-9-]{0,239}$`: 1-240 chars, lowercase letters, digits and `-`, starting with a letter or digit. |
| `dkms_instance_id` | `string` | yes | Existing KMS instance the key is created in (ForceNew); not empty. The instance is bought outside this repository. |
| `description` | `string` | no | Default `null`. Key description. |
| `key_spec` | `string` | no | Default `Aliyun_AES_256` (ForceNew). Allowed (symmetric only): `Aliyun_AES_256`, `Aliyun_AES_192`, `Aliyun_AES_128`, `Aliyun_SM4`. |
| `rotation_interval` | `string` | no | Default `365d`. A positive integer plus one unit `d`, `h`, `m` or `s` (regex `^[1-9][0-9]*[dhms]$`, for example `365d`, `8760h`, `31536000s`). The period must be 7 to 365 days (604800 to 31536000 seconds). The module sends it normalised to seconds (`365d` becomes `31536000s`) because the API returns seconds and the provider does not suppress the difference. `null` disables rotation (`automatic_rotation = Disabled`). |
| `pending_window_in_days` | `number` | no | Default `30`. Days a deleted key stays recoverable; whole number 7-366. |
| `deletion_protection` | `bool` | no | Default `false`. |
| `tags` | `map(string)` | yes | Resource tags. At least one tag is required; keys and values must not be empty. |

## Outputs

| Name | Description |
|---|---|
| `tags` | Tags applied to the key. |
| `rotation_interval` | Rotation period in seconds as sent to the key (`null` when disabled). |
| `automatic_rotation` | `Enabled` or `Disabled`. |
| `key_id` | Key ID, passed to ECS `kms_key_id` / RDS `encryption_key`. |
| `arn` | Key ARN. |
| `alias` | Alias name, `alias/<name>`. |

## Notes

- `key_usage` is fixed to `ENCRYPT/DECRYPT`.
- A new key does not re-encrypt existing disks or instances.
- Disabling or deleting a key in use locks every disk and RDS instance encrypted with it; hence deletion protection and the 30-day pending window default.

## Instances wrapper

`instances/` calls this module once per map entry (`for_each`), so one state holds many keys. Use it from a leaf as `source = ".../modules//kms/instances"`.

| Input | Meaning |
|---|---|
| `instances` | Map (`any`), at least one entry. The map key becomes `name`. Each value takes `dkms_instance_id`, `description`, `key_spec`, `rotation_interval`, `pending_window_in_days`, `deletion_protection`, `tags`. Unset fields are passed as `null`, so the module defaults apply, except `rotation_interval`: an unset field is `"365d"` (`try(..., "365d")`); set it to `null` explicitly to disable rotation. `dkms_instance_id` has no default and must be set (read directly, so a missing one fails). Entries with any other key fail validation (typo protection). |
| `tags` | Shared tags, at least one; keys and values must not be empty. Merged under each entry's own `tags` (the entry wins on a clash). |

Output `instances` returns every output of this module, keyed by entry name.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```
