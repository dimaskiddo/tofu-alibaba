# cen

Creates a Cloud Enterprise Network (CEN) Enterprise Edition hub for one region: a CEN instance (`alicloud_cen_instance`, skipped when `cen_id` is given), the region's transit router (`alicloud_cen_transit_router`), VPC attachments, optional inter-region peer attachments, and for every attachment the association with and propagation to the transit router's system route table. Associated and propagating attachments form a full mesh: every attached VPC learns the CIDRs of the others.

CEN carries no traffic by itself. The VPC side needs a route to the other CIDRs with `nexthop_type = "Attachment"` and the attachment ID (`attachment_ids` output); add it with the `route-table` module. This module adds no VPC routes. Security group rules for the remote CIDRs are still needed.

Provider: `aliyun/alicloud ~> 1.293`. OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Default | Description |
|---|---|---|---|---|
| `cen_name` | `string` | yes | | Name of the CEN instance and the transit router, `<component>-<instance>-c1-<tenant>-<env>`. 2-128 chars, lowercase letters, digits and `-`, starting with a letter, not ending with `-`. |
| `cen_id` | `string` | no | `null` | Existing CEN (`cen-...`) to add this region's transit router to. Null creates the CEN instance in this stack. |
| `description` | `string` | no | `null` | Description of the CEN instance and the transit router. |
| `zones` | `list(string)` | yes | | Registered zones, at least one. Every `zone_id` of an attachment must be in it. |
| `vpc_attachments` | `map(object)` | no | `{}` | VPC attachments by name (same name rules as `cen_name`). Each: `vpc_id` (`vpc-...`), `zone_mappings` (1-10 of `vswitch_id` `vsw-...` and `zone_id`), optional `description`. With two or more registered zones the mappings must cover at least two distinct zones. |
| `peer_attachments` | `map(object)` | no | `{}` | Inter-region attachments by name. Each: `peer_transit_router_id` (`tr-...`), `peer_region_id` (a region ID such as `ap-southeast-5`, not the provider region; the latter is enforced by a precondition), `bandwidth` (positive integer, Mbit/s), optional `link_type` (`Gold` default, or `Platinum`). Billed by data transfer. |
| `remote_attachment_ids` | `map(string)` | no | `{}` | Attachments created by the other region's leaf (name to ID), associated and propagated into this transit router's system table. Names and IDs must be non-empty (names follow the `cen_name` pattern). A name must be unique across this map and the two maps above. |
| `tags` | `map(string)` | yes | | Resource tags. At least one tag is required; keys and values must not be empty. |

## Outputs

| Name | Description |
|---|---|
| `cen_id` | CEN instance ID (created, or the `cen_id` input). |
| `transit_router_id` | Transit router ID of this region. |
| `route_table_id` | System route table ID of the transit router. |
| `attachment_ids` | VPC and peer attachment IDs by name; an `Attachment` route next hop, or another region's `remote_attachment_ids`. |
| `tags` | Tags applied to the transit router. |

## Notes

- **Service activation (manual, once per account).** The Transit Router service must be opened before the first apply, otherwise the API returns `Forbbiden.TransitRouterServiceNotOpen`. The only Terraform route is the data source `alicloud_cen_transit_router_service`, which activates at plan time and cannot be undone, so an Atlantis autoplan would open it as a side effect. It is therefore not part of this module or any leaf; open it once in the console.
- Enterprise Edition only: Basic Edition and `alicloud_cen_instance_attachment` are not sold in Alibaba Cloud International regions.
- One transit router per region per CEN. A second region runs the module with `cen_id` set, its own provider region and its own state; `peer_region_id` must differ from the provider region.
- The system route table is not exported by the transit router resource, so it is read with `alicloud_cen_transit_router_route_tables` (type `System`). Each attachment can be associated with only one table; custom tables are not modelled.
- ForceNew: the transit router's `cen_id`, an attachment's `vpc_id`, and a peer attachment's peer router ID and region. Association and propagation are replaced when the attachment or table changes. `force_delete` is left off, so routes pointing at an attachment must be removed first.
- Inter-region: each region's leaf creates its own transit router; one side sets `peer_attachments`, the other side passes the resulting attachment ID in `remote_attachment_ids` to associate and propagate it. Traffic is billed through Cloud Data Transfer.
- Billing: each attachment is charged an hourly connection fee plus traffic processing.
- Association and propagation resources take no tags; they are the only untagged resources.
- Import: a VPC attachment as `<cen_id>:<attachment_id>`.

## Instances wrapper

`instances/` calls this module once per map entry (`for_each`), so one state holds many instances. Use it from a leaf as `source = ".../modules//cen/instances"`.

| Input | Type | Meaning |
|---|---|---|
| `instances` | `any` | At least one entry. The map key becomes `cen_name`. Each value takes `cen_id`, `description`, `vpc_attachments`, `peer_attachments`, `remote_attachment_ids`, `tags`; keys outside that list, and unknown keys inside an attachment, fail validation. Attachment names must be unique across all entries. |
| `zones` | `list(string)` | Registered zones shared by every entry, at least one. |
| `tags` | `map(string)` | Shared tags, at least one; `merge`d under each entry's own `tags` (the entry wins on a clash). |

Output `instances` returns every output of this module keyed by entry name. `attachment_ids` is a separate top-level output that merges the attachment IDs of all entries, so a leaf can resolve an attachment by name.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```
