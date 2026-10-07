# redis

Creates one pay-as-you-go in-memory database: Redis OSS (`alicloud_kvstore_instance`) or Tair (`alicloud_redis_tair_instance`), chosen by `instance_type`. Tags propagate to the instance.

Provider: `aliyun/alicloud ~> 1.293`, `hashicorp/random ~> 3.7`. OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | yes | Instance name, `<component>-<instance>-c1-<tenant>-<env>`. 2-80 chars: lowercase letters, digits and `-`, starting with a letter and not ending with `-`. |
| `instance_type` | `string` | yes | `Redis` (OSS), `tair_rdb`, `tair_scm` or `tair_essd`. |
| `engine_version` | `string` | yes | `Redis` and `tair_rdb`: `5.0`, `6.0`, `7.0`. `tair_scm`: `1.0`. `tair_essd`: `1.0`, `2.0`. |
| `instance_class` | `string` | yes | Region specific, for example `redis.master.small.default` or `tair.rdb.2g`; not empty. List what the region sells before choosing. |
| `vpc_id` | `string` | Tair only | Default `null`. VPC ID; required for the Tair types (ForceNew), ignored by `Redis`, which derives the VPC from `vswitch_id`. |
| `vswitch_id` | `string` | yes | vSwitch ID (`vsw-...`) in `zone_id` (ForceNew on Tair). |
| `zone_id` | `string` | yes | Primary zone, non-empty. |
| `secondary_zone_id` | `string` | no | Default `null`. Standby zone, must differ from `zone_id`. |
| `shard_count` | `number` | no | Default `null` (class default). Whole number, cluster classes only: 2-256 for `Redis`, 2-32 for Tair. |
| `storage_size_gb` | `number` | `tair_essd` 1.0 | Default `null`. Disk size in GB of an ESSD instance (ForceNew). Required for `tair_essd` with `engine_version` 1.0 (ESSD), rejected otherwise (`2.0` is SSD with a fixed size). |
| `storage_performance_level` | `string` | no | Default `null`. `PL1`, `PL2` or `PL3`, `tair_essd` 1.0 only (ForceNew). PL1 fits 4C-16C, PL2 8C-52C, PL3 16C-52C classes. |
| `security_ips` | `list(string)` | yes | 1-1000 IPv4 addresses or CIDRs; a bare `0.0.0.0` and any `/0` are rejected. |
| `deletion_protection` | `bool` | no | Default `null`, which sends `false`. Only valid for `Redis`; the Tair resource has no release protection and the module rejects the input. |
| `password` | `string` | no | Default `null`, sensitive. Default-account password, 8-32 chars from letters, digits and `!@#$%^&*()_+=-`, at least 3 of 4 classes. Null generates a random one. |
| `password_length` | `number` | no | Default `16`. 8-32; length of a generated password. |
| `tags` | `map(string)` | yes | At least one tag; keys and values not empty. |

## Outputs

| Name | Description |
|---|---|
| `instance_id` | Instance ID. |
| `connection_domain` | Internal connection address. |
| `tags` | Tags applied. |
| `generated_passwords` | Sensitive. `{ default = <password> }` when generated, empty when `password` was supplied. |

## Notes

- Destroy-and-create: changing `instance_type` (it switches the resource), and on Tair `secondary_zone_id`, `vpc_id`, `vswitch_id`, `zone_id`, `storage_size_gb`, `storage_performance_level`.
- Billing is fixed to pay-as-you-go. PrePaid destroy only removes the instance from state, so it is not offered.
- Skipped, add when needed: TDE (irreversible once enabled), backup and maintenance windows (Alibaba defaults apply), per-application ACL accounts (only the default account exists).
- The password is stored in state as a sensitive value; protect the state backend.
- Not verifiable offline: `secondary_zone_id` support per class, and the Tair field set. Check on the first plan in a test account.

## Instances wrapper

`instances/` calls this module once per map entry (`for_each`). Use it from a leaf as `source = ".../modules//redis/instances"`.

| Input | Meaning |
|---|---|
| `instances` | Map (`any`), at least one entry; the key becomes `name`. Each value takes `instance_type`, `engine_version`, `instance_class`, `vpc_id`, `vswitch_id`, `zone_id`, `secondary_zone_id`, `shard_count`, `storage_size_gb`, `storage_performance_level`, `security_ips`, `deletion_protection`, `password_length`, `tags`. `instance_type`, `engine_version`, `instance_class`, `vswitch_id`, `zone_id` and `security_ips` are required; `vpc_id` is optional here and the module requires it only for the Tair types. Any other key fails validation. |
| `tags` | Shared tags, merged under each entry's own `tags`. |
| `redis_passwords` | `map(string)`, default `{}`, sensitive. Instance name to password. A key not in `instances` fails validation. |

Output `instances` returns every module output per instance except `generated_passwords`; output `generated_passwords` is a separate sensitive map: instance name, then `default`.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```
