# vpc

Creates one VPC. Tags propagate to `alicloud_vpc`.

Provider: `aliyun/alicloud ~> 1.293`. OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Default | Description |
|---|---|---|---|---|
| `vpc_name` | `string` | yes | | VPC name, `<component>-<instance>-c1-<tenant>-<env>`. Validated: 2-128 chars, lowercase letters, digits and `-`, starting with a letter, not ending with `-`. |
| `cidr_block` | `string` | yes | | VPC IPv4 CIDR block, e.g. `10.0.0.0/16`; must be an IPv4 CIDR with no host bits set (IPv6 and `10.0.0.1/16` are rejected). The mask must be /16 to /28 (CreateVpc). |
| `description` | `string` | no | `null` | Optional VPC description. |
| `tags` | `map(string)` | yes | | Resource tags. At least one tag is required; keys and values must not be empty. |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | VPC ID. |
| `vpc_name` | VPC name. |
| `cidr_block` | VPC CIDR block. |
| `route_table_id` | System route table ID. |
| `tags` | Tags applied to the VPC. |

## Instances wrapper

`instances/` calls this module once per map entry (`for_each`), so one state holds many instances. Use it from a leaf as `source = ".../modules//vpc/instances"`.

| Input | Type | Meaning |
|---|---|---|
| `instances` | `any` | At least one entry. The map key becomes `vpc_name`. `cidr_block` is required; `description` defaults to `null`, `tags` to `{}`. Entries with any other key fail validation (typo protection). |
| `tags` | `map(string)` | Shared tags, at least one, keys and values non-empty; `merge`d under each entry's own `tags` (the entry wins on a clash). |

Output `instances` is a map keyed by entry name; each value holds `vpc_id`, `vpc_name`, `cidr_block`, `route_table_id` and the merged `tags`.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```
