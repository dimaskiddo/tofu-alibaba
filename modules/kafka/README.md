# kafka

Creates one pay-as-you-go ApsaraMQ for Kafka instance (VPC only) with topics, consumer groups, the VPC IP allow-list, SASL users and their ACLs. Tags propagate to the instance.

Provider: `aliyun/alicloud ~> 1.293`, `hashicorp/random ~> 3.7`. OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | yes | Instance name, `<component>-<instance>-c1-<tenant>-<env>`. 3-64 chars: lowercase letters, digits and `-`, starting with a letter and not ending with `-`. |
| `partition_num` | `number` | yes | Partition quota of the instance, at least 1. |
| `disk_type` | `string` | yes | `ssd` or `cloud_efficiency`. ForceNew. |
| `disk_size` | `number` | yes | GB, 500-6100 in steps of 100. Only grows. A higher `io_max_spec` may need a larger minimum; that is not checked. |
| `io_max_spec` | `string` | yes | Traffic spec such as `alikafka.hw.2xlarge`; not empty. Region specific. |
| `spec_type` | `string` | no | Default `normal`. `normal`, `professional` or `professionalForHighRead`. SASL users need a professional edition. |
| `service_version` | `string` | no | Default `2.2.0`. `2.2.0` or `2.6.2`. |
| `placement` | `list(object)` | yes | One or two `{ zone_id, vswitch_id }` in distinct zones; two entries make a multi-zone instance (sent as `selected_zones`). |
| `security_group_id` | `string` | no | Default `null` (Alibaba Cloud creates one). ForceNew. |
| `allowed_ips` | `list(string)` | yes | Unique IPv4 CIDRs, at most 200 (a bare IP is rejected: use `/32`; the provider stores the value verbatim in the attachment ID); any `/0` is rejected. Opened on port `9092/9092`, and on `9094/9094` when SASL users exist. |
| `topics` | `list(object)` | no | Default `[]`. `{ name, partition_num = 12 (1-360), remark, compact_topic = false, local_topic = false }`. Name 3-64 chars of letters, digits, `.`, `_`, `-`, not starting with `__`; unique. Partition minimum is 2 on cloud storage and 1 on local storage. `compact_topic` needs `local_topic`, and `local_topic` needs `spec_type` professional (the standard edition refuses it); compacted topics need an Alibaba support ticket. `compact_topic` and `local_topic` are ForceNew. `remark` is 3-64 chars of letters, digits, `_`, `-` (no `.`) and defaults to the name with `.` replaced by `-`. |
| `consumer_groups` | `list(object)` | no | Default `[]`. `{ name, remark }`. Name 3-64 chars of letters, digits, `.`, `_`, `-` (no `__` rule); `remark` as for topics. ForceNew (name and remark). |
| `sasl_users` | `list(object)` | no | Default `[]`. `{ name, type = "scram" (plain or scram), acls = [{ resource_type, resource_name, pattern = "LITERAL", operation }] }`. `resource_type` Topic, Group, Cluster or TransactionalId; `pattern` LITERAL or PREFIXED; `operation` Write, Read, Describe or IdempotentWrite. `name` 1-64 chars of letters, digits, `_`, `-`; `resource_name` non-empty; identical ACLs on one user are rejected. Any user sets `enable.acl` on the instance. |
| `sasl_passwords` | `map(string)` | no | Default `{}`, sensitive. User name to password, 8-64 chars of letters, digits and `_`. A user without an entry gets a random one; an entry for an unknown user is rejected. |
| `password_length` | `number` | no | Default `16`. 8-64; length of generated passwords. |
| `tags` | `map(string)` | yes | At least one tag; keys and values not empty. |

## Outputs

| Name | Description |
|---|---|
| `instance_id` | Instance ID. |
| `end_point` | Default (plaintext) endpoint. |
| `domain_endpoint` | Domain name endpoint. |
| `vpc_sasl_domain_endpoint` | SASL endpoint (port 9094). |
| `topic_names`, `consumer_group_names`, `sasl_user_names` | Names created. |
| `tags` | Tags applied. |
| `generated_passwords` | Sensitive. Random SASL passwords keyed by user; supplied ones are absent. |

## Notes

- Destroy-and-create: `placement` vSwitch or zone, `disk_type`, `security_group_id`, a consumer group's name or remark. `disk_size` cannot shrink.
- Billing is fixed to pay-as-you-go (`deploy_type = 5`, VPC only; no public endpoint, no `eip_max`).
- Topics and groups are removed when dropped from the list; their messages go with them.
- SASL passwords are letters, digits and `_` only. They are stored in state as sensitive values.
- Not verifiable offline: `vswitch_ids` with `deploy_type = 5`, `enable.acl` through `config`, and whether multi-zone needs `professional`. Check on the first plan in a test account.

## Instances wrapper

`instances/` calls this module once per map entry. Use it from a leaf as `source = ".../modules//kafka/instances"`.

| Input | Meaning |
|---|---|
| `instances` | Map (`any`), at least one entry; the key becomes `name`. Each value takes `partition_num`, `disk_type`, `disk_size`, `io_max_spec`, `spec_type`, `service_version`, `placement`, `security_group_id`, `allowed_ips`, `topics`, `consumer_groups`, `sasl_users`, `password_length`, `tags`. `partition_num`, `disk_type`, `disk_size`, `io_max_spec`, `placement` and `allowed_ips` are required. Any other key fails validation, and so does an unknown key inside `placement`, `topics`, `consumer_groups`, `sasl_users` or an ACL. |
| `tags` | Shared tags, merged under each entry's own `tags`. |
| `kafka_sasl_passwords` | `map(map(string))`, default `{}`, sensitive. Instance name, then user name. An instance key not in `instances` fails validation. |

Output `instances` returns every module output per instance except `generated_passwords`; output `generated_passwords` is a separate sensitive map: instance name, then user name.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```
