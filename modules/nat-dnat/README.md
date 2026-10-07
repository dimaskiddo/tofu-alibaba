# nat-dnat

Creates DNAT (forward) entries (`alicloud_forward_entry`) in an existing forward table, one resource per entry keyed by `name`. `alicloud_forward_entry` has no tags argument; `tags` is required for contract parity only and is not applied.

Provider: `aliyun/alicloud ~> 1.293` (the only `required_providers` entry). OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `forward_table_id` | `string` | yes | DNAT (forward) table ID of the NAT gateway (nat module output `forward_table_ids`). Must start with `ftb-`. |
| `entries` | `list(object({ name = string, external_ip = string, external_port = string, internal_ip = string, internal_port = string, ip_protocol = optional(string, "tcp"), port_break = optional(bool, false) }))` | yes | DNAT entries, at least one. See the rules below. |
| `tags` | `map(string)` | yes | Resource tags. At least one tag is required; keys and values must not be empty. Accepted for contract parity only: the provider resource is not taggable. |

Rules for `entries`:

- `name`: required, unique, 2-128 chars: lowercase letters, digits and `-`, starting with a letter and not ending with `-`.
- `external_ip`, `internal_ip`: required, valid IPv4 addresses.
- `ip_protocol`: `tcp` (default), `udp` or `any`.
- `external_port`, `internal_port`: required strings. With `tcp`/`udp`: a single port (for example `"80"`) or a range `first/last` (for example `"10/20"`), each number 1-65535 and `first <= last`; the two ports must cover the same number of ports. With `any`: both must be `"any"`.
- `port_break`: bool, default `false`.
- Each `external_ip:external_port:ip_protocol` may appear in only one entry. Port ranges on one `external_ip` must not overlap within a protocol, and an `any` mapping owns its whole `external_ip`.
- A non-numeric port is reported once by the port-format check; the range and size checks skip entries whose ports are not well formed.

## Outputs

| Name | Description |
|---|---|
| `dnat_entry_ids` | DNAT entry IDs keyed by entry name. |

## Instances wrapper

`instances/` calls this module once per map entry (`for_each`), so one state holds many instances. Use it from a leaf as `source = ".../modules//nat-dnat/instances"`.

| Input | Meaning |
|---|---|
| `instances` | Map (`any`), at least one entry. The map key only identifies the instance in the output. Each value takes `forward_table_id`, `entries`, `tags`. `forward_table_id` and `entries` are required and read directly, so a missing one fails at plan; the wrapper adds no defaults. Keys outside that list fail validation (a typo is an error, not a silent null). Entries of different instances on one `forward_table_id` are checked for overlap on the same `external_ip`. |
| `tags` | `map(string)`. Shared tags, at least one, keys and values not empty; merged under each entry's own `tags`. Accepted for contract parity only; the provider resource is not taggable. |

Output `instances` returns every output of this module keyed by entry name.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```
