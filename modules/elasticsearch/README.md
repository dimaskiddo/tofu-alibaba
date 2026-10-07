# elasticsearch

Creates one pay-as-you-go Alibaba Cloud Elasticsearch instance (`alicloud_elasticsearch_instance`) reachable only from the VPC. Tags propagate to the instance.

Provider: `aliyun/alicloud ~> 1.293`, `hashicorp/random ~> 3.7`. OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | yes | Sent as the instance `description`. 2-128 chars: lowercase letters, digits and `-`, starting with a letter and not ending with `-`. |
| `es_version` | `string` | yes | For example `7.10_with_X-Pack` or `8.5.1_with_X-Pack`. ForceNew on a minor change. (Named `es_version` because `version` is reserved in a module block.) |
| `vswitch_id` | `string` | yes | vSwitch ID (`vsw-...`). Extra zones of a multi-zone instance are chosen by Alibaba Cloud. ForceNew. |
| `zone_count` | `number` | no | Default `1`. 1-3. ForceNew. More than 1 needs `master_node_spec`. |
| `data_node` | `object` | yes | `{ spec, amount, disk, disk_type = "cloud_essd", performance_level }`. `amount` 2-50 and a multiple of `zone_count`; `disk` GB, at least 20; `disk_type` cloud_ssd, cloud_essd or cloud_efficiency (ForceNew); `performance_level` PL1-PL3, required for cloud_essd and rejected otherwise. |
| `master_node_spec` | `string` | no | Default `null`. Adds 3 dedicated masters (20 GB `cloud_ssd` each, the only master disk type). Required when `zone_count` > 1; not empty. Master amount, disk and disk type are ForceNew, so adding masters to an existing cluster can force replacement. |
| `kibana_node_spec` | `string` | no | Default `null`. Adds one Kibana node and enables Kibana private network access; not empty. |
| `protocol` | `string` | no | Default `HTTP`. `HTTP` or `HTTPS`. |
| `private_whitelist` | `list(string)` | yes | IPv4 addresses or CIDRs allowed on the VPC endpoint, at most 300; a bare `0.0.0.0` and any `/0` are rejected. A CIDR's address part must be the network address (Alibaba FAQ; not validated). |
| `password` | `string` | no | Default `null`, sensitive. Password of user `elastic`, 8-32 chars from letters, digits and `!@#$%^&*()_+=-`, at least 3 of 4 classes. Null generates a random one. |
| `password_length` | `number` | no | Default `16`. 8-32. |
| `tags` | `map(string)` | yes | At least one tag; keys and values not empty. |

## Outputs

| Name | Description |
|---|---|
| `instance_id` | Instance ID. |
| `domain`, `port` | Internal Elasticsearch endpoint. |
| `kibana_private_domain`, `kibana_port` | Private Kibana endpoint inside the VPC and its port. |
| `kibana_domain` | Public Kibana endpoint; public access is never enabled, so use `kibana_private_domain`. |
| `tags` | Tags applied. |
| `generated_passwords` | Sensitive. `{ elastic = <password> }` when generated, empty when supplied. |

## Notes

- Public Elasticsearch and public Kibana access are forced off (Alibaba Cloud enables public Kibana by default). Public access would need a reviewed exception.
- Destroy-and-create: `es_version` minor, `vswitch_id`, `zone_count`, data `disk_type`.
- The resource has no deletion protection: removing it from the configuration deletes the cluster and its data. Review every plan for a destroy.
- Billing is fixed to pay-as-you-go; creation waits up to 120 minutes.
- Skipped, add when needed: warm and client nodes, `setting_config` (known drift), disk encryption.
- Instance classes are region specific.
- Not verifiable offline: HTTPS creation, the default delete type and the create duration. Check on the first plan in a test account.

## Instances wrapper

`instances/` calls this module once per map entry. Use it from a leaf as `source = ".../modules//elasticsearch/instances"`.

| Input | Meaning |
|---|---|
| `instances` | Map (`any`), at least one entry; the key becomes `name`. Each value takes `es_version`, `vswitch_id`, `zone_count`, `data_node`, `master_node_spec`, `kibana_node_spec`, `protocol`, `private_whitelist`, `password_length`, `tags`. `es_version`, `vswitch_id`, `data_node` and `private_whitelist` are required. Any other key fails validation, and so does an unknown key inside `data_node`. |
| `tags` | Shared tags, merged under each entry's own `tags`. |
| `elasticsearch_passwords` | `map(string)`, default `{}`, sensitive. Instance name to password. A key not in `instances` fails validation. |

Output `instances` returns every module output per instance except `generated_passwords`; output `generated_passwords` is a separate sensitive map: instance name, then `elastic`.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```
