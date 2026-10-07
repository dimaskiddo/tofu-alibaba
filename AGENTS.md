# OpenTofu for Alibaba Cloud — Agent Instructions

Infrastructure-as-code platform for Alibaba Cloud: reusable OpenTofu modules, Terragrunt implementors, Atlantis-driven PR/MR execution. Never weaken a security, state, validation, or deployment control to make a plan/test pass — stop and surface the ambiguity.

---

## Workflow Rules

1. Read `TASKS.md` and project docs before every session when they exist. At minimum orient against `README.md`, `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/WORKFLOWS.md` and the module/implementation docs relevant to the task.
2. Never rework items marked `[x]` in `TASKS.md` unless explicitly instructed.
3. Update `TASKS.md` immediately after completing a task when `TASKS.md` exists.
4. Never rewrite the entire repository in a single change unless explicitly requested.
5. Before changing shared modules, identify every known implementor under `deploy/` that consumes the affected module.
6. Prefer the smallest change that preserves module contracts, state boundaries, naming conventions, and Atlantis project behavior.
7. Do not silently change state keys, backend types, provider configuration, resource naming, or module inputs/outputs. They are compatibility-sensitive.

---

## Skills & Caveman Mode

*   **GLOBAL:** All prompts processed as if `"Use caveman mode full"` is injected.
*   Before ANY coding task, invoke and read: `using-superpowers`, `karpathy-guidelines`, `caveman`.
*   Use `using-superpowers` to route to other relevant skills; use the repository's engineering/IaC skills when present.
*   Prefer built-in OpenTofu/Terragrunt commands and repository scripts over ad-hoc shell pipelines.
*   Before changing Atlantis configuration, inspect the existing `atlantis.yaml` and repository-level Atlantis conventions.
*   Before changing state behavior, inspect the relevant Terragrunt `remote_state`/backend generation and state identity convention.
*   When a task touches Alibaba Cloud resource semantics, verify the provider resource/data source contract instead of guessing field names or lifecycle behavior.

---

## Architecture

Two layers: `modules/` (reusable implementation, never owns deployment state) and `deploy/` (Terragrunt implementors composing modules into tenant/environment stacks). Detail: `docs/ARCHITECTURE.md`.

| Component | Role |
|---|---|
| **VPC** `modules/vpc` | VPC and stable VPC outputs. |
| **Subnet** `modules/subnet` | vSwitch topology, including multi-zone mappings. |
| **EIP** `modules/eip` | EIP resources and optional associations. |
| **NAT** `modules/nat` | Enhanced NAT gateways, internet and intranet (NAT IP CIDR, transit IPs, route). |
| **NAT SNAT / DNAT** `modules/nat-snat`, `modules/nat-dnat` | Source and destination NAT entries, port mappings. |
| **Security Group** `modules/security-group` | Security groups and rules. |
| **VPC Peering** `modules/vpc-peering` | Same-account peering, intra- or inter-region (requester side; cross-account accepter not modelled), and its peer-CIDR routes. |
| **Route Table** `modules/route-table` | Custom route tables (optional vSwitch binding) or routes in an existing VPC route table. |
| **KMS** `modules/kms` | Keys and aliases inside an existing KMS instance. |
| **OSS** `modules/oss` | Private or public buckets: 30s settle wait, public-access block, ACL, RAM-user bucket policy, encryption, versioning, lifecycle. |
| **RAM** `modules/ram` | RAM user with one AccessKey, principal of bucket policies. |
| **RDS** `modules/rds` | MySQL, PostgreSQL, MariaDB with backup policy, databases, accounts, privileges. |
| **Redis** `modules/redis` | Redis OSS (`alicloud_kvstore_instance`) or Tair (`alicloud_redis_tair_instance`), chosen by `instance_type`. |
| **MongoDB** `modules/mongodb` | ApsaraDB for MongoDB replica set (`alicloud_mongodb_instance`) or sharded cluster (`alicloud_mongodb_sharding_instance`), chosen by `architecture`; backup policy, read-only nodes, cloud-disk encryption, parameters. |
| **Kafka** `modules/kafka` | Instance, topics, consumer groups, VPC allow-list, SASL users and ACLs. |
| **Elasticsearch** `modules/elasticsearch` | VPC-only cluster, optional dedicated masters and Kibana. |
| **ECS** `modules/ecs` | Instances, user data (first boot, ignored after create), key pairs, data disks, generated passwords, network/security group attachments. |
| **CLB / ALB** `modules/slb-clb`, `modules/slb-alb` | Classic and Application Load Balancers: listeners, backends, zones, server groups, rules. |
| **CEN** `modules/cen` | CEN Enterprise Edition transit router for one region: CEN (or existing `cen_id`), VPC and inter-region peer attachments, system route table association and propagation. |
| **CBWP** `modules/cbwp` | Shared bandwidth package; attaches EIPs and Internet-facing ALBs. |
| **Provider Layer** | Root/deploy-generated provider config supplies region and credentials. Child modules never hardcode credentials. |
| **State Layer** | Terragrunt/implementor layer owns remote state. |
| **Implementor** `deploy/<tenant>-<env>/...` | Module inputs, dependencies, region, zones, tags, naming, state identity. |
| **Atlantis** `atlantis.yaml` | Which deployment directories are PR/MR execution projects. |
| **Example Tenant** `deploy/example-*` | Reference-only copy/paste documentation; never an Atlantis execution target. |

Layering: `deploy/* implementor → modules/* → Alibaba Cloud provider`. No reverse dependency: a module never reads files from `deploy/` or depends on another tenant's implementation files.

---

## Backend Families & State Identity

| Type | Locking |
|---|---|
| `oss` | Tablestore row (`LockID`); needs `tablestore_endpoint` and `tablestore_table` |
| `s3` | `use_lockfile`; S3-compatible only, not Alibaba OSS (cannot lock) |
| `gitlab` | HTTP lock/unlock |
| `gitea` | HTTP lock/unlock |
| `http` | HTTP LOCK/UNLOCK |

*   Logical identity: `<tenant>/<environment>/<leaf path>/<stack>.tfstate`. Stack = leaf path with `/` replaced by `-`, then `-<tenant>-<env>`. One leaf has one state; every instance file in the leaf shares it.
*   Examples: `example/stage/vpc/vpc-example-stage.tfstate`, `example/stage/ecs/ecs-example-stage.tfstate`, `example/stage/nat/snat/nat-snat-example-stage.tfstate`.

---

## Commands

```sh
tofu fmt -check -recursive modules              # module formatting
(cd deploy && terragrunt hcl fmt --check)       # Terragrunt formatting
(cd modules/<m> && tofu init -backend=false && tofu test)   # module unit tests (also modules/<m>/instances)
bash scripts/validate-tenant.sh [tenant ...]    # offline validate; exit 0 OK, 1 validation failure, 2 bad tenant argument
bash scripts/check-atlantis.sh                  # atlantis.yaml guard; prints "atlantis guard OK"
bash scripts/check-deploy.sh                    # leaf guard; prints "leaf guard OK"
```

---

## Critical Constraints

### Naming
*   Format `<component>-<instance>-c1-<tenant>-<env>`; `c1` is the fixed infix, separator `-`. Examples: `vpc-1-c1-example-stage`, `bastion-1-c1-example-stage`, `nat-1-c1-example-stage`.
*   Deterministic; no random suffix unless the Alibaba Cloud API requires uniqueness that cannot otherwise be guaranteed. `tenant` and `env` explicit. Names valid under the target API constraints.
*   A rename can be destructive: inspect lifecycle and downstream dependencies first. Never replace a stable production identifier (or swap in a random one) just to pass validation.

### Region
*   Every deployment has an explicit region, from the tenant's `provider.hcl`; `deploy/root.hcl` validates it (`region_ok`) and generates `provider.tf`. Another provider generation mechanism only by explicit decision.
*   No resolvable region must fail before resource creation.

### Zones
*   Where zone topology is part of the contract: `variable "zones"` is `list(string)`, `nullable = false`, validation `length(var.zones) >= 1`. Minimum one zone.
*   Multi-zone is data, not hardcoded. Consume the declared zone set; never silently collapse it to the first element.
*   Modules taking `zones`: subnet, ecs, cen, slb-alb, slb-clb. Value comes from `provider.hcl` through root `inputs.zones`.

### Tags
*   Every provisionable component accepts `variable "tags"`: `map(string)`, `nullable = false`, at least one tag, no empty keys or values (where the API permits validation). Exact snippet: `docs/ARCHITECTURE.md` §4.
*   Tenant tags are defined once in `deploy/<tenant>-<env>/tenant.hcl` as `base_tags = { env = local.environment }` and forwarded unchanged by `deploy/root.hcl` and every leaf. `root.hcl` holds no tag values; a tenant without `base_tags` fails before any resource.
*   Each instance file adds its own tags, merged over the tenant tags (instance wins on a clash) by the `instances/` wrappers; ecs and eip merge inside the module, subnet in `modules/subnet/main.tf`.
*   Propagate tags to every taggable resource; never silently discard supplied tags.

### Remote State
*   Belongs to the implementor layer, never to reusable modules. No deployment backend in a child module. No hardcoded state credentials.
*   Credentials and passwords are injected as tenant-prefixed environment variables (`EXAMPLE_STAGE_STATE_ACCESS_KEY_ID`, `EXAMPLE_STAGE_ALIBABA_CLOUD_ACCESS_KEY_ID`, `EXAMPLE_STAGE_ECS_PASSWORD`, listed in `README.md`). `deploy/root.hcl` maps them to the names the provider and backend read; a missing required one fails before any resource.
*   Isolate state by tenant/environment/stack. Locking is mandatory where supported. Never commit state contents, backend tokens, access keys, passwords or credentials. State is sensitive infrastructure metadata.
*   Never manually rewrite a state object outside an explicit recovery/migration procedure. Backend migration is a controlled change: backup plus plan verification.

### Atlantis
*   PR/MR execution gate: `Pull/Merge Request → Atlantis → Terragrunt → OpenTofu → Alibaba Cloud`. OpenTofu is the distribution.
*   Production-capable deployment directories are explicit projects. Prefer `autodiscover.mode: disabled`. `atlantis.yaml` currently has `projects: []` and `automerge: false`; tenants add their own project blocks.
*   Each project identifies: project name, deployment directory, OpenTofu distribution, workflow. `name` is `<tenant>-<env>-<leaf>`, unique; `dir` is one leaf = one state. Block and rules: `docs/WORKFLOWS.md` "Register Atlantis projects".
*   Projects live only in the root `atlantis.yaml` (no per-tenant file), are hand-written one per leaf, written out in full; no generator or script. `when_modified` per component: own `*.hcl`, tenant files, `root.hcl`, `_common`, own module `*.tf`; subnet uses `**/*.hcl`, dnat also `../snat/*.hcl`. Shared module changes need explicit `when_modified` coverage; changing `modules/*` must trigger plans for affected implementors.
*   Plan and apply operate on the same reviewed change/plan lifecycle. Never bypass Atlantis approval with local auto-apply automation. Project boundaries align with state boundaries. Atlantis lock does not replace backend state locking.
*   `deploy/example-*` is never a project; `scripts/check-atlantis.sh` checks it.

### Terragrunt
*   Implementation layer: module source, environment/tenant config, dependency wiring, backend and provider generation, shared locals, consistent tags.
*   A leaf has one entrypoint, `terragrunt.hcl`, which is wiring only. Every value you change lives in an instance file next to it, keyed by its `name`. The leaf's `known`/`unknown`/`keys_ok` locals fail on an unknown instance-file key instead of ignoring a typo. Leaf pattern: `docs/ARCHITECTURE.md` §3.
*   Prefer `dependency.*.outputs` over hardcoded IDs for repo-managed resources. Do not duplicate module code under `deploy/`. Avoid hidden behavior that makes local differ from Atlantis. Generated provider/backend files deterministic.

### OpenTofu
*   Pin versions per repository policy; keep provider constraints explicit. Do not silently upgrade providers during unrelated tasks.
*   Keep per-leaf `.terraform.lock.hcl` in the tree (kept in version control once the repo has commits), generated with `providers lock` for linux_amd64, darwin_amd64, darwin_arm64 and windows_amd64; regenerate only for a deliberate provider change.
*   Use `tofu fmt`, `tofu validate`, `tofu plan` as appropriate. Do not assume Terraform-only behavior; verify the supported OpenTofu version.

### Module Boundaries
*   Modules are self-contained and provider-aware but deployment-agnostic. No tenant names, environment names, state bucket names, GitLab project IDs, Gitea package paths or production resource IDs inside a module. Not tied to a particular Atlantis project.
*   Inputs and outputs are public contracts for implementors.
*   Required properties: explicit inputs and outputs, validation for critical topology, mandatory `tags`, no credentials, no environment-specific hardcoding, deterministic names, stable outputs, no hidden backend. Files: `versions.tf`, `vars.tf`, `main.tf`, `output.tf`; optional `locals.tf`, `instances/` (for_each wrapper), `data.tf`, `validation.tf`, `README.md`, `examples/`, `tests/`.

### Provider and Credentials
*   Credentials come from environment/secret injection or another approved external mechanism. Never commit AccessKey ID/Secret, security token, API token, backend password or private credential material. Do not echo secrets through shell debugging or Terraform/OpenTofu logging. Region explicit and deterministic.
*   Provider aliases only for a documented multi-account/multi-region requirement.
*   **Exception (owner decision, 2026-10-01; extended 2026-10-02 to the RAM AccessKey of `modules/ram`; extended 2026-10-04 to the Redis/Tair default-account password, the Kafka SASL user passwords and the Elasticsearch `elastic` password; extended 2026-10-07 to the MongoDB `root` password):** secrets the modules generate for ECS and RDS logins (random passwords, `generate_key_pair` private keys), the AccessKey ID and secret of each RAM user, and the Redis, Kafka, Elasticsearch and MongoDB passwords are printed after apply by the single `terragrunt` Atlantis workflow and appear in the MR/PR comment. Everyone with read access to the MR/PR and its email notifications sees them, so rotate them after the first login. The workflow posts any stack output named `generated_passwords` and any `*.pem` file in the leaf directory, then deletes the `.pem` files (also when the apply fails); do not reuse that output name for anything else. Secrets supplied by the operator (`EXAMPLE_STAGE_ECS_PASSWORD`, `EXAMPLE_STAGE_RDS_ACCOUNT_PASSWORDS`, `EXAMPLE_STAGE_REDIS_PASSWORDS`, `EXAMPLE_STAGE_KAFKA_SASL_PASSWORDS`, `EXAMPLE_STAGE_ELASTICSEARCH_PASSWORDS`, `EXAMPLE_STAGE_MONGODB_PASSWORDS`) are never output.

### State, Plan/Apply and Dependency Safety
*   Never disable state locking to work around contention. Never point two unrelated stacks at one state identity. Never delete remote state to resolve a normal plan/apply problem. Never run state surgery without an explicit recovery/migration procedure. Preserve isolation across tenants and environments.
*   Agents may inspect, format, validate, lint and plan. Agents must not run `apply`, `destroy`, `state rm`, `state mv`, backend migration or provider upgrade against a shared/production environment without explicit instruction. Never auto-approve or auto-merge a PR/MR. Never auto-trigger production deployment.
*   If a dependency changes output shape, update all consumers explicitly. Do not hide dependency failures with mock outputs in production paths. Test dependency graphs with the directory boundaries Atlantis will use.

### Example Tenant Safety
*   `deploy/example-*` is the reference-only copy/paste template for new tenants: no credentials or live production endpoints, never an Atlantis project, never an unintended apply target; local validation allowed. It demonstrates tenant/env variables, explicit region, zones, mandatory tags, state identity, naming, module source, dependency usage, and every module (EIPs, public/private NAT, VPC peering, route tables, subnets in `subnet/<vpc-name>/` folders, security groups, ECS, CLB, ALB, KMS, RAM, OSS, RDS, Redis/Tair, MongoDB, Kafka, Elasticsearch, CBWP, CEN with a hub and a spoke VPC attachment).
*   New tenant: copy → rename tenant/env → replace region, zones, CIDRs, state identity → review dependencies → create PR/MR (`docs/WORKFLOWS.md` §1).

### Testing
*   Layers: `tofu fmt -check -recursive`, `terragrunt hcl fmt --check`, `tofu validate` from the right root/module context, `tofu test`. Use repository-approved static analysis only.
*   No scanner is adopted (2026-10-02): tflint has no alicloud ruleset, trivy has no alicloud checks, checkov (`CKV_ALI_*`) is not adopted. Validation blocks and `tofu test` are the gate. Do not add a new security scanner just because it is available.
*   Cover at least: tags required, region required, zones minimum of 1, invalid CIDR rejected, invalid port rejected, required resource references, single-zone behavior, multi-zone behavior, stable outputs, dependency wiring where applicable.
*   Integration tests may provision real resources in a dedicated test account and must: use isolated state, use dedicated credentials, use a non-production tenant/environment, verify outputs and topology, clean up afterwards, never reuse production state.

### Error Handling
*   Fail early on invalid region, zone, tag, CIDR, name or required dependency inputs. Never coerce invalid topology into a valid-looking plan. Do not swallow provider errors. Do not convert a failed remote-state lock into an unlocked apply.
*   Error messages identify the invalid configuration without printing secrets. Prefer explicit validation blocks over hidden runtime assumptions.

### Provider and Interface Changes
*   Before changing the Alibaba Cloud provider constraint: (1) identify consuming modules; (2) inspect resource/data source compatibility; (3) run formatting/validation; (4) run plans for affected implementors; (5) verify state compatibility; (6) document behavior changes.
*   Before changing a module input/output: (1) find all implementors; (2) assess backward compatibility; (3) update the example tenant; (4) update tests; (5) run affected plans.

### No Stubbing
*   Every function/configuration/module is complete and production-ready. No TODO, FIXME, placeholder resource IDs, dummy credentials, "rest of code", or commented-out production code.
*   For an incomplete feature, implement the validation boundary and fail clearly rather than pretending a working resource exists.

---

## Non-Negotiable Rules

1. **No stubs.** Every module and configuration path must be complete.
2. **No guessing** on Alibaba Cloud resource semantics, provider behavior, state locking, backend behavior, or lifecycle semantics.
3. **Never auto-commit.** Provide the diff; the user commits manually.
4. **Never auto-apply.** Provide the exact validation/plan command and expected result; apply only when explicitly requested.
5. **Never weaken state locking.** Locking exists to prevent concurrent destructive changes.
6. **Never hardcode secrets.**
7. **Never bypass Atlantis governance** for environments that are configured for Atlantis.
8. **Never register `deploy/example-*` as an Atlantis project.**
9. **Minimal comments.** Comments explain WHY, not WHAT or step-by-step mechanics.
10. **Do not hide destructive behavior.** Flag renames, replacements, deletes, state changes, and provider upgrades explicitly.
11. **Do not silently modify completed infrastructure.** If a resource is already correct, do not churn it.
12. **Do not change state identity casually.** A backend key is part of the deployment contract.
13. **Do not introduce `count`/`for_each` refactors casually** on existing managed resources; address changes can cause state churn or recreation.
14. **Do not use broad wildcard data sources** where an explicit resource identifier or dependency output is available.
15. **Keep production execution deterministic.**

---

## PR / Change Review Checklist

```text
[ ] Module contract preserved            [ ] State identity unchanged unless intentionally migrated
[ ] Region still explicit                [ ] Backend locking remains enabled
[ ] zones >= 1                           [ ] No secret material added
[ ] Multi-zone behavior preserved/tested [ ] Example tenant updated if interface changed
[ ] tags still mandatory                 [ ] Affected deploy/* implementors identified
[ ] Naming remains <component>-<instance>-c1-<tenant>-<env>
[ ] Atlantis project coverage reviewed   [ ] Example tenant remains excluded from Atlantis
[ ] fmt/validate/tests completed         [ ] Plan reviewed for unexpected destroy/replace
```

---

## Directory Tree

```text
.
├── deploy/
│   ├── root.hcl                    # Root include: provider/backend generation, state key, env mapping, instance discovery, guards
│   ├── _common/state.hcl           # Backend templates
│   ├── example-stage/              # Reference tenant (never an Atlantis project)
│   │   ├── README.md               # How to fill every instance file
│   │   ├── provider.hcl            # Region, zones
│   │   ├── tenant.hcl              # Tenant, env, base_tags, state settings
│   │   ├── vpc/                    # One leaf = one state: wiring-only terragrunt.hcl + instance files
│   │   │   ├── terragrunt.hcl
│   │   │   └── vpc-1-c1-example-stage.hcl
│   │   ├── subnet/                 # Instance files grouped in <vpc-name>/ folders
│   │   ├── eip/ security-group/ ecs/ kms/ ram/ oss/ rds/ cbwp/
│   │   ├── redis/ mongodb/ kafka/ elasticsearch/
│   │   ├── vpc-peering/ route-table/ cen/
│   │   ├── nat/                    # nat-1, nat-2; snat/ and dnat/ are their own leaves
│   │   └── slb/                    # clb/ and alb/ leaves
│   └── <tenant>-<env>/             # Real tenants, same shape
│
├── modules/                        # Reusable modules, no backend/provider/credentials
│   ├── vpc/                        # versions.tf vars.tf main.tf output.tf README.md tests/ instances/
│   ├── vpc-peering/ route-table/ cen/ subnet/ eip/ nat/ nat-snat/ nat-dnat/
│   ├── security-group/ ecs/ kms/ ram/ oss/ rds/ cbwp/
│   ├── redis/ mongodb/ kafka/ elasticsearch/
│   └── slb-clb/ slb-alb/
│
├── docs/
│   ├── ARCHITECTURE.md             # Module map, leaf/state/credential internals, landing zone, design decisions
│   └── WORKFLOWS.md                # MR-to-apply pipeline, onboarding, Atlantis projects, apply order, CI, error recovery
│
├── scripts/
│   ├── check-atlantis.sh           # atlantis.yaml guard
│   ├── check-deploy.sh             # Leaf, env and backend guard
│   └── validate-tenant.sh          # Offline validate of any tenant
│
├── atlantis.yaml                   # Projects, single terragrunt workflow, autodiscovery disabled
├── TASKS.md                        # Work items
├── README.md                       # Overview, onboarding, credentials, commands
├── AGENTS.md                       # This file
├── CLAUDE.md -> AGENTS.md
├── GEMINI.md -> AGENTS.md
├── LICENSE                         # MIT
└── .gitignore
```

Modules carry no backend or provider file; `deploy/root.hcl` generates `provider.tf` and `backend.tf` per leaf.

---

## References

| File | Purpose |
|---|---|
| `README.md` | Purpose, prerequisites, onboarding, credential variable table, commands. |
| `docs/ARCHITECTURE.md` | Module map, root include and guards, leaf/instance files, module contract, state, credentials, landing zone, design decisions. |
| `docs/WORKFLOWS.md` | MR-to-apply pipeline, tenant onboarding, Atlantis project block, apply order, CI validation, secrets, lock files, error recovery. |
| `TASKS.md` | Current work items and task state. |
| `modules/*/README.md` | Module contract, inputs, outputs, examples, resource notes. |
| `deploy/example-*` | Copy/paste reference implementation for new tenants. |
| `atlantis.yaml` | Project boundaries, the single `terragrunt` workflow, OpenTofu distribution, autoplan policy. |
| `deploy/root.hcl` | Root include: provider and backend generation, state key, env-var mapping, instance discovery, tag forwarding, input guards. |
| `deploy/_common/*` | Backend templates (`state.hcl`). |
| `scripts/*.sh` | `check-atlantis.sh`, `check-deploy.sh`, `validate-tenant.sh`. |
| `.terraform.lock.hcl` | Per-leaf locked provider selections for four platforms, committed in every example leaf. |

---

## Final Rule

Preserve: module contract + state isolation + Atlantis governance + deterministic naming + explicit region/zone topology + mandatory tagging + secret-free source control. When a requested change conflicts with one of these, do not silently choose a workaround. Surface the conflict and preserve the infrastructure safety boundary.
