# oss

Creates one private or public OSS bucket with a bucket policy for one RAM user, server-side encryption, optional versioning and lifecycle rules.

Provider: `aliyun/alicloud ~> 1.293`, `hashicorp/time ~> 0.14`. OpenTofu `>= 1.10.0, < 1.11.0`. The module holds no backend, provider configuration or credentials; the Terragrunt implementor supplies them.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | yes | Bucket name, `<component>-<instance>-c1-<tenant>-<env>`. Must match `^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$`: 3-63 chars, lowercase letters, digits and `-`, starting and ending with a letter or digit. Global across all Alibaba Cloud customers (ForceNew). |
| `storage_class` | `string` | no | Default `Standard`. Allowed: `Standard`, `IA`, `Archive`, `ColdArchive`, `DeepColdArchive` (ForceNew). |
| `redundancy_type` | `string` | no | Default `LRS`. Allowed: `LRS`, `ZRS` (ForceNew). |
| `visibility` | `string` | no | Default `private`. Allowed: `private` (public access blocked, ACL `private`), `public` (block off, ACL `public-read`: anonymous read of every object). |
| `ram_user_id` | `string` | yes | Numeric RAM user ID (`modules/ram` `user_id`, must match `^[0-9]+$`); the only principal of the bucket policy. |
| `versioning` | `string` | no | Default `null` (versioning off). Allowed: `Enabled`, `Suspended`, `null`. Once enabled it can only be suspended, never removed. |
| `sse_algorithm` | `string` | no | Default `AES256` (OSS-managed key). Allowed: `AES256`, `KMS`. |
| `kms_master_key_id` | `string` | no | Default `null`. Only valid with `sse_algorithm = "KMS"` (lifecycle precondition on the bucket fails otherwise); `null` with `KMS` uses the OSS service key. |
| `lifecycle_rules` | `list(object)` | no | Default `[]`. See the object below. |
| `force_destroy` | `bool` | no | Default `false`. Deletes the bucket even when it holds objects; keep `false` outside throwaway stacks. |
| `tags` | `map(string)` | yes | Resource tags. At least one tag is required; keys and values must not be empty. |

`lifecycle_rules` element:

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | `string` | yes | Rule ID; unique across the list. |
| `prefix` | `string` | no | Default `""` (whole bucket). |
| `enabled` | `bool` | no | Default `true`. |
| `expiration_days` | `number` | no | Default `null` (no action). |
| `abort_multipart_upload_days` | `number` | no | Default `null` (no action). |
| `noncurrent_version_expiration_days` | `number` | no | Default `null` (no action). |
| `transitions` | `list(object({ days = number, storage_class = string }))` | no | Default `[]`. `days` and `storage_class` are required per entry; `days` must be smaller than the rule's `expiration_days`; `storage_class` is `IA`, `Archive`, `ColdArchive` or `DeepColdArchive`. |

Every rule needs at least one action (`expiration_days`, `abort_multipart_upload_days`, `noncurrent_version_expiration_days` or a transition). All day counts are whole numbers >= 1.

## Outputs

| Name | Description |
|---|---|
| `tags` | Tags applied to the bucket. |
| `bucket` | Bucket name. |
| `extranet_endpoint` | Public (extranet) endpoint of the bucket. |
| `intranet_endpoint` | Internal (intranet) endpoint of the bucket. |
| `visibility` | `private` or `public`. |

## Order of operations

bucket -> `time_sleep` 30s -> public-access block -> ACL -> bucket policy. OSS rejects these calls right after creation, and a public ACL is rejected while the block is on, so the block is set first. The bucket's inline `policy` is ignored (`ignore_changes`) because the separate resource owns it; the inline `acl` is deprecated, computed and never set, so it is neither configured nor ignored.

The bucket policy is the same for both visibilities: it allows the RAM user `GetObject`, `PutObject`, `DeleteObject`, `ListObjects`, `AbortMultipartUpload`, `ListParts`, `ListMultipartUploads` and `GetBucketInfo` on the bucket and its objects, and nothing else. Bucket admin actions are left out so the AccessKey cannot undo the module.

Prerequisites: a public bucket fails while the account-level Block Public Access is on. The wait is fixed at 30s.

## Instances wrapper

`instances/` calls this module once per map entry (`for_each`), so one state holds many buckets. Use it from a leaf as `source = ".../modules//oss/instances"`.

| Input | Meaning |
|---|---|
| `instances` | Map (`any`), at least one entry. The map key becomes the bucket `name`. Each value takes `storage_class`, `redundancy_type`, `visibility`, `ram_user_id`, `versioning`, `sse_algorithm`, `kms_master_key_id`, `lifecycle_rules`, `force_destroy`, `tags`. Unset fields are passed as `null`, so the module defaults above apply; `ram_user_id` has no default and must be set. Entries with any other key fail validation (typo protection), and so does an unknown key inside `lifecycle_rules` or its `transitions`. |
| `tags` | Shared tags, at least one; keys and values must not be empty. Merged under each entry's own `tags` (the entry wins on a clash). |

Output `instances` returns every output of this module, keyed by entry name.

## Tests

```bash
tofu init -backend=false -input=false && tofu test
(cd instances && tofu init -backend=false -input=false && tofu test)
```

The `time` provider comes from the registry.
