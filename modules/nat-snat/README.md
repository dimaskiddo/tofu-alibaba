# nat-snat

Creates SNAT entries (`alicloud_snat_entry`) in an existing SNAT table, one resource per entry keyed by `name`. `alicloud_snat_entry` has no tags argument; `tags` is required for contract parity only and is not applied.

Provider: `aliyun/alicloud ~> 1.293` (the only `required_providers` entry). OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `snat_table_id` | `string` | yes | SNAT table ID of the NAT gateway (nat module output `snat_table_ids`). Must start with `stb-`. |
| `snat_ips` | `list(string)` | yes | Public EIP addresses (internet NAT) or NAT IPs (private NAT) used as translated source. At least one; each must be a valid IPv4 address and distinct. Joined with `,` into `snat_ip`. |
| `entries` | `list(object({ name = string, source_cidr = optional(string), source_vswitch_id = optional(string) }))` | yes | SNAT entries, at least one. `name` is required and unique, 2-128 chars: lowercase letters, digits and `-`, starting with a letter and not ending with `-`. Exactly one of `source_cidr` (IPv4 CIDR with no host bits set) or `source_vswitch_id` (must start with `vsw-`) per entry. Each `source_cidr` and each `source_vswitch_id` may appear in only one entry. |
| `tags` | `map(string)` | yes | Resource tags. At least one tag is required; keys and values must not be empty. Accepted for contract parity only: the provider resource is not taggable. |

## Outputs

| Name | Description |
|---|---|
| `snat_entry_ids` | SNAT entry IDs keyed by entry name. |
| `snat_ip` | Translated source IPs, comma separated. |

## Instances wrapper

`instances/` calls this module once per map entry (`for_each`), so one state holds many instances. Use it from a leaf as `source = ".../modules//nat-snat/instances"`.

| Input | Meaning |
|---|---|
| `instances` | Map (`any`), at least one entry. The map key only identifies the instance in the output. Each value takes `snat_table_id`, `snat_ips`, `entries`, `tags`. `snat_table_id`, `snat_ips` and `entries` are required and read directly, so a missing one fails at plan; the wrapper adds no defaults. Keys outside that list fail validation (a typo is an error, not a silent null). Two entries on one `snat_table_id` must not share a `source_vswitch_id` or `source_cidr`. |
| `tags` | `map(string)`. Shared tags, at least one, keys and values not empty; merged under each entry's own `tags`. Accepted for contract parity only; the provider resource is not taggable. |

Output `instances` returns every output of this module keyed by entry name.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```
