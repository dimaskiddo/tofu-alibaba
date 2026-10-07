# cbwp

Creates one shared bandwidth package (Alibaba Cloud Common Bandwidth Package) and attaches EIPs and Internet-facing ALBs to it. The attached addresses share the package bandwidth instead of each paying for its own.

Provider: `aliyun/alicloud ~> 1.293`. OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | yes | Package name, `<component>-<instance>-c1-<tenant>-<env>`. Must match `^[a-z][a-z0-9-]{0,126}[a-z0-9]$`. |
| `bandwidth` | `number` | yes | Shared Mbit/s, whole number 1-1000. Changed in place. |
| `internet_charge_type` | `string` | no | Default `PayByBandwidth`; or `PayByTraffic`. ForceNew. Pay-by-traffic packages are limited to 5 per account and region. |
| `isp` | `string` | no | Default `BGP`; or `BGP_PRO` (only some regions). ForceNew. Must equal the ISP of every attached EIP. |
| `description` | `string` | no | Default `null`. 2-256 characters. |
| `deletion_protection` | `bool` | no | Default `false`. |
| `eip_ids` | `map(string)` | no | Default `{}`. EIP name => allocation ID (`eip-...`), at most 100. |
| `alb_ids` | `map(string)` | no | Default `{}`. ALB name => load balancer ID (`alb-...`). |
| `tags` | `map(string)` | yes | Resource tags. At least one tag is required; keys and values must not be empty. |

## Outputs

| Name | Description |
|---|---|
| `tags` | Tags applied to the package. |
| `bandwidth_package_id` | Package ID. |
| `eip_names` | Sorted names of the attached EIPs. |
| `alb_names` | Sorted names of the attached ALBs. |

## Notes

- An attached EIP must be PayAsYouGo, in the same region and with the package ISP. While attached, the package bandwidth applies; the EIP's own `bandwidth` and `internet_charge_type` stay in its state. Removing the attachment restores the EIP's own bandwidth and billing.
- An ALB must be Internet-facing; the API rejects an intranet ALB at apply. `modules/slb-alb` ignores `bandwidth_package_id` on the load balancer, because inline it is ForceNew and the attachment here sets it.
- CLB is not supported: the provider has no bandwidth package argument for it.
- Attachments have no tags in the provider; only the package is tagged.
- The package takes the provider default `PayAsYouGo`; the module does not set `payment_type`. PayBy95, `ratio`, `security_protection_types`, `resource_group_id` and a per-EIP cap are not exposed.
- A package with attachments cannot be deleted; with `deletion_protection = true` the delete fails until it is switched off.

## Instances wrapper

`instances/` calls this module once per map entry (`for_each`), so one state holds many packages. Use it from a leaf as `source = ".../modules//cbwp/instances"`.

| Input | Meaning |
|---|---|
| `instances` | Map (`any`), at least one entry. The map key becomes the package `name`. Each value takes `bandwidth` (required), `internet_charge_type`, `isp`, `description`, `deletion_protection`, `eip_ids`, `alb_ids`, `tags`. Entries with any other key fail validation (typo protection). |
| `tags` | Shared tags, at least one; keys and values must not be empty. Merged under each entry's own `tags` (the entry wins on a clash). |

Output `instances` returns every output of this module keyed by entry name.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```
