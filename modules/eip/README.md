# eip

Creates EIPs keyed by name and, when `instance_id` is set, an `alicloud_eip_association`. The EIP-to-NAT association is done in the `nat` module, not here.

Provider: `aliyun/alicloud ~> 1.293`. OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `eips` | `list(object)` | yes | EIPs to create, at least one; see the object below. |
| `tags` | `map(string)` | yes | Resource tags. At least one tag is required; keys and values must not be empty. Applied to every EIP; a member's `tags` merge over them for that EIP only (the member wins on a clash). |

`eips` element:

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | yes | EIP name, `<component>-<instance>-c1-<tenant>-<env>`; unique within the list and the key of both outputs. Must match `^[a-z][a-z0-9-]{0,126}[a-z0-9]$`: 2-128 chars, lowercase letters, digits and `-`, starting with a letter and not ending with `-`. |
| `bandwidth` | `number` | no | Default `5`. Whole number of Mbit/s, 1-200. Updated in place. |
| `internet_charge_type` | `string` | no | Default `PayByTraffic`, the only accepted value: EIPs are pay-as-you-go and international accounts sell pay-as-you-go only with `PayByTraffic` (`PayByBandwidth` needs a subscription, which the module does not offer; the API answers `COMMODITY.INVALID_COMPONENT`). ForceNew in the provider. |
| `isp` | `string` | no | Default `BGP`. `BGP` or `BGP_PRO`. ForceNew: replaces the EIP and its address. |
| `description` | `string` | no | Default `null`. |
| `instance_id` | `string` | no | Default `null`. Associates the EIP with an ECS instance, ENI (`eni-...`) or HAVIP (`havip-...`); must start with `i-`, `eni-` or `havip-` when set. `instance_type` is derived from the prefix: `eni-` sets `NetworkInterface`, `havip-` sets `HaVip`, anything else leaves the provider default `EcsInstance`. `ngw-...` is rejected: the nat module owns the NAT association. |
| `tags` | `map(string)` | no | Default `{}`. Keys and values must not be empty. |

`payment_type` is fixed to `PayAsYouGo`; subscription is not supported (`payment_type` is ForceNew in the provider).

## Outputs

| Name | Description |
|---|---|
| `eip_ids` | EIP allocation IDs keyed by EIP name. |
| `eip_addresses` | EIP public IP addresses keyed by EIP name. |
| `tags` | Tags applied to each EIP, keyed by EIP name. |

## Instances wrapper

None. This module takes a list through `eips`; a leaf calls it directly (`source = ".../modules/eip"`), one state per leaf.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
```
