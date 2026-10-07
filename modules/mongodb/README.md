# mongodb

Creates one pay-as-you-go ApsaraDB for MongoDB instance: a replica set (`alicloud_mongodb_instance`) or a sharded cluster (`alicloud_mongodb_sharding_instance`), chosen by `architecture`. Tags propagate to the instance.

Provider: `aliyun/alicloud ~> 1.293`, `hashicorp/random ~> 3.7`. OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | yes | Instance name, `<component>-<instance>-c1-<tenant>-<env>`. 2-256 chars: lowercase letters, digits and `-`, starting with a letter and not ending with `-`. |
| `architecture` | `string` | yes | `replica_set` or `sharded`. Switching it swaps the resource and replaces the instance. |
| `engine_version` | `string` | yes | `4.0`, `4.2`, `4.4`, `5.0`, `6.0`, `7.0` or `8.0`. |
| `instance_class` | `string` | `replica_set` | Default `null`. Node class, region specific, for example `mdb.shard.4x.large.d`. Rejected for `sharded`. |
| `storage_gb` | `number` | `replica_set` | Default `null`. Disk size in GB: a whole multiple of 10, at least 10. Rejected for `sharded`. |
| `replication_factor` | `number` | no | Default `null` (provider default). `1` (standalone), `3`, `5` or `7`. `replica_set` only. |
| `readonly_replicas` | `number` | no | Default `null`. 0-5 read-only nodes. `replica_set` only. |
| `mongos` | `list(object)` | `sharded` | Default `[]`. 2-32 entries `{ node_class }`. Must stay empty for `replica_set`. |
| `shards` | `list(object)` | `sharded` | Default `[]`. 2-32 entries `{ node_class, node_storage, readonly_replicas }`; `node_storage` a multiple of 10, `readonly_replicas` optional 0-5. Must stay empty for `replica_set`. |
| `config_server` | `object` | no | Default `null`. `{ node_class, node_storage }`. `sharded` only (ForceNew). |
| `storage_type` | `string` | no | Default `null` (provider default: `cloud_essd1` from 4.4, `local_ssd` for 4.2 and earlier). `cloud_essd1`, `cloud_essd2`, `cloud_essd3`, `cloud_auto` (China site only) or `local_ssd`. ForceNew. |
| `vpc_id` | `string` | yes | VPC ID (`vpc-...`) (ForceNew). |
| `vswitch_id` | `string` | yes | vSwitch ID (`vsw-...`) in `zone_id` (ForceNew). |
| `zone_id` | `string` | yes | Primary zone, non-empty (ForceNew). |
| `secondary_zone_id` | `string` | no | Default `null`. Secondary zone, must differ from `zone_id`. Cloud disk only. |
| `hidden_zone_id` | `string` | no | Default `null`. Hidden node zone, must differ from `zone_id` and `secondary_zone_id`. Cloud disk only. |
| `security_ips` | `list(string)` | yes | 1-1000 distinct IPv4 addresses or CIDRs; a bare `0.0.0.0` and any `/0` are rejected. |
| `deletion_protection` | `bool` | no | Default `false`. Set `true` to block release; switch it off and apply before a destroy. |
| `backup` | `object` | no | Default `null` (Alibaba defaults). `{ period, time, retention_days }`: `period` a list of distinct weekday names (`Monday` ... `Sunday`), `time` a one-hour UTC window such as `17:00Z-18:00Z`, `retention_days` an optional whole number of at least 1. |
| `disk_encryption_key_id` | `string` | no | Default `null` (no encryption). KMS key ID for cloud-disk encryption (ForceNew). Needs a cloud disk. |
| `parameters` | `map(string)` | no | Default `{}`. Engine parameter name to value; keys and values not empty. |
| `password` | `string` | no | Default `null`, sensitive. `root` password, 8-32 chars from letters, digits and `!@#$%^&*()_+=-`, at least 3 of 4 classes. Null generates a random one. |
| `password_length` | `number` | no | Default `16`. 8-32; length of a generated password. |
| `tags` | `map(string)` | yes | At least one tag; keys and values not empty. |

## Outputs

| Name | Description |
|---|---|
| `instance_id` | Instance ID. |
| `replica_set_name` | Replica set name for the connection string; `null` for `sharded`. |
| `endpoints` | List of `{ role, domain, port }`: one entry per replica-set role, or one per mongos node (`role = "mongos"`). |
| `tags` | Tags applied. |
| `generated_passwords` | Sensitive. `{ root = <password> }` when generated, empty when `password` was supplied. |

## Notes

- Destroy-and-create: changing `architecture`, `vpc_id`, `vswitch_id`, `zone_id`, `storage_type`, `disk_encryption_key_id`, or `config_server`. Mongos and shard lists, storage and class change in place.
- Zones: a single `zone_id` is one-zone. A cloud-disk replica set may add `secondary_zone_id` and `hidden_zone_id`; all three must differ, so a hidden zone needs three registered zones.
- The account is `root`. The password is stored in state as a sensitive value; protect the state backend.
- Billing is fixed to pay-as-you-go. PrePaid destroy only removes the instance from state, so it is not offered.
- Skipped, add when needed: TDE (conflicts with disk encryption), SSL, maintenance window, log backup, extra accounts, `storage_engine`, `provisioned_iops`, named whitelist groups, the DynamoDB protocol.
- Not verifiable offline: class names and minimum disk per region. List what the region sells before choosing.

## Instances wrapper

`instances/` calls this module once per map entry (`for_each`). Use it from a leaf as `source = ".../modules//mongodb/instances"`.

| Input | Meaning |
|---|---|
| `instances` | Map (`any`), at least one entry; the key becomes `name`. Each value takes every module input except `name` and `password`. `architecture`, `engine_version`, `vpc_id`, `vswitch_id`, `zone_id` and `security_ips` are required. Any other key fails validation. |
| `tags` | Shared tags, merged under each entry's own `tags`. |
| `mongodb_passwords` | `map(string)`, default `{}`, sensitive. Instance name to `root` password. A key not in `instances` fails validation. |

Output `instances` returns every module output per instance except `generated_passwords`; output `generated_passwords` is a separate sensitive map: instance name, then `root`.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```
