#!/usr/bin/env bash
# Leaf contract: terragrunt.hcl holds wiring only; every user-editable value lives in instance files.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

# Static: tenant names, CIDRs and regions must not appear in any leaf terragrunt.hcl.
# mock_outputs may use include.root.locals.mock, which is generic.
while IFS= read -r f; do
  if grep -nE -e '-c1-' -e '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+' -e '\b[a-z]{2}-[a-z]+-[0-9]+[a-z]?\b' "$f" | grep -v '^\s*[0-9]*:\s*#' ; then
    echo "FAIL: $f holds a user value (tenant name, CIDR or region)"; fail=1
  fi
done < <(find "$root/deploy" -name terragrunt.hcl -not -path '*/.terragrunt-cache/*')
# Bare IPs: mock_outputs blocks hold legitimate dummy addresses and are skipped.
while IFS= read -r f; do
  if awk '/^  mock_outputs = \{/{m=1} m&&/^  \}$/{m=0;next} !m' "$f" | grep -nE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | grep -v '^[0-9]*:\s*#'; then
    echo "FAIL: $f holds an IP address"; fail=1
  fi
done < <(find "$root/deploy" -name terragrunt.hcl -not -path '*/.terragrunt-cache/*')

# Static: leaves forward the tenant's base_tags unchanged; tags are defined in tenant.hcl and instance files only.
while IFS= read -r f; do
  if grep -nE '^  tags *= ' "$f" | grep -Ev '^[0-9]+:  tags = include\.root\.locals\.base_tags$'; then
    echo "FAIL: $f: a top-level tags line must be exactly include.root.locals.base_tags"; fail=1
  fi
  if grep -nE 'tags *= *merge\(' "$f"; then
    echo "FAIL: $f adds tags in the leaf; put them in the instance files"; fail=1
  fi
  if grep -nE '\b[A-Z][A-Z0-9]+_[A-Z0-9_]+\b' "$f" | grep -Ev '^[0-9]+: *#'; then
    echo "FAIL: $f names an upper-case tenant prefix; root.hcl maps tenant env vars"; fail=1
  fi
done < <(find "$root/deploy" -name terragrunt.hcl -not -path '*/.terragrunt-cache/*')
# Env vars and shell commands are read in root.hcl only; instance files and leaves get them through include.root.locals.
while IFS= read -r f; do
  if grep -nE 'get_env\(|run_cmd\(' "$f"; then
    echo "FAIL: $f calls get_env/run_cmd; only deploy/root.hcl may"; fail=1
  fi
done < <(find "$root/deploy" -name '*.hcl' -not -name root.hcl -not -path '*/.terragrunt-cache/*')
if grep -nE 'base_tags *= *\{' "$root/deploy/root.hcl"; then
  echo "FAIL: deploy/root.hcl holds a tag value; define base_tags in tenant.hcl"; fail=1
fi

# Negative: broken leaf layouts must be rejected with their message.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fresh() { # copy deploy/ into $tmp so a case can edit it freely
  rm -rf "$tmp/deploy" && cp -r "$root/deploy" "$tmp/deploy" && ln -sfn "$root/modules" "$tmp/modules"
  find "$tmp/deploy" -name .terragrunt-cache -type d -prune -exec rm -rf {} +
}
tg() { # leaf dir, then terragrunt args; inherited tenant/TF_VAR variables are dropped so the caller's shell cannot change the outcome, CASE_ENV is re-applied
  local dir="$1" v; shift
  local unset_args=()
  while IFS= read -r v; do unset_args+=(-u "$v"); done < <(env | sed -nE 's/^((EXAMPLE_STAGE_|TF_VAR_)[A-Za-z0-9_]*)=.*/\1/p')
  (cd "$dir" && env "${unset_args[@]}" "${CASE_ENV[@]}" TG_TF_PATH=tofu terragrunt "$@" --non-interactive 2>&1 || true)
}
CASE_ENV=()
expect() { # leaf, name, expected message fragment, setup command run inside the leaf
  local leaf="$1" name="$2" msg="$3"; shift 3
  fresh
  local dir="$tmp/deploy/example-stage/$leaf"
  (cd "$dir" && "$@")
  local out
  out="$(tg "$dir" ${CMD:-render --json})"
  if grep -q -- "$msg" <<<"$out"; then echo "ok: $name rejected"; else echo "FAIL: $name not rejected"; fail=1; fi
}
expect vpc "empty leaf" "no instance file" sh -c 'for f in *-c1-*.hcl; do mv "$f" ".$f.bak"; done'
expect subnet "duplicate subnet name across VPC folders" "Duplicate object key" cp vpc-1-c1-example-stage/subnet-a-1-c1-example-stage.hcl vpc-2-c1-example-stage/
expect vpc "instance file without name" "without a name value" sed -i '/^  name  *=/d' vpc-1-c1-example-stage.hcl
expect vpc "duplicate name in two files" "Duplicate object key" sh -c 'cp vpc-1-c1-example-stage.hcl copy.hcl'
expect vpc "tenant without base_tags" "must define base_tags" sed -i '/base_tags *=/d' ../tenant.hcl
expect vpc "tenant.hcl not matching its directory" "must equal the tenant directory name" sed -i 's/^  tenant  *= .*/  tenant      = "copied"/' ../tenant.hcl
expect vpc "tenant ending in -" "tenant must match" sed -i 's/^  tenant  *= .*/  tenant      = "example-"/' ../tenant.hcl
expect vpc "unknown state.type" "state.type must be one of" sed -i 's/type  *= "oss"/type = "s4"/' ../tenant.hcl
expect vpc "blank state setting" "state.oss is missing settings: bucket" sed -i 's/bucket  *= "example-tfstate"/bucket = "  "/' ../tenant.hcl
expect vpc "region not a region ID" "region must be an Alibaba Cloud region ID" sed -i 's/region = .*/region = "Jakarta"/' ../provider.hcl
expect vpc "oss without tablestore_table" "missing settings: tablestore_table" sed -i '/tablestore_table/d' ../tenant.hcl
expect vpc "s3 against an OSS endpoint" "cannot lock on Alibaba OSS" sed -i '/tablestore_/d;s/type  *= "oss"/type = "s3"/' ../tenant.hcl
expect vpc "unknown instance key" "unknown key(s) descripton" sed -i 's/^  description *=/  descripton = "typo"\n  description =/' vpc-1-c1-example-stage.hcl
expect security-group "unknown rule key" "unknown rule key(s) polcy" sed -i 's/policy *=/polcy =/;0,/{ name = "ssh-vpc"/s//{ polcy = "drop", name = "ssh-vpc"/' sg-1-c1-example-stage.hcl

expect vpc-peering "same-region peering with a literal accepter ID" "a same-region peering needs accepting_vpc" sed -i 's/^  routes = false/  routes = false\n  accepting_vpc_id = "vpc-abc"/' peer-1-c1-example-stage.hcl
expect nat/dnat "dnat entry without an address" "set eip or transit_ip" sed -i '/^  eip  *=/d;/^  transit_ip  *=/d' dnat-1-c1-example-stage.hcl

# plan needs the tenant-prefixed credentials; the message fails at parse time, before any network call.
CMD=plan expect vpc "plan without tenant credentials" "EXAMPLE_STAGE_ALIBABA_CLOUD_ACCESS_KEY_ID" true
CASE_ENV=(TF_VAR_password=x EXAMPLE_STAGE_ALIBABA_CLOUD_ACCESS_KEY_ID=a EXAMPLE_STAGE_ALIBABA_CLOUD_ACCESS_KEY_SECRET=b EXAMPLE_STAGE_STATE_ACCESS_KEY_ID=c EXAMPLE_STAGE_STATE_SECRET_ACCESS_KEY=d)
CMD=plan expect vpc "global TF_VAR_password" "global TF_VAR_password is set" true
CASE_ENV=(TF_VAR_region=cn-hangzhou EXAMPLE_STAGE_ALIBABA_CLOUD_ACCESS_KEY_ID=a EXAMPLE_STAGE_ALIBABA_CLOUD_ACCESS_KEY_SECRET=b EXAMPLE_STAGE_STATE_ACCESS_KEY_ID=c EXAMPLE_STAGE_STATE_SECRET_ACCESS_KEY=d)
CMD=plan expect vpc "global TF_VAR_region" "global TF_VAR_region is set" true
CASE_ENV=(TF_VAR_password=x EXAMPLE_STAGE_ALIBABA_CLOUD_ACCESS_KEY_ID=a EXAMPLE_STAGE_ALIBABA_CLOUD_ACCESS_KEY_SECRET=b EXAMPLE_STAGE_STATE_ACCESS_KEY_ID=c EXAMPLE_STAGE_STATE_SECRET_ACCESS_KEY=d)
CASE_ENV+=(ALICLOUD_PROFILE=other)
CMD=plan expect vpc "global ALICLOUD_PROFILE" "global ALICLOUD_PROFILE is set" true
CASE_ENV=()

# Positive: the prefixed password must reach tofu as TF_VAR_password through the leaf's include.
fresh
CASE_ENV=(EXAMPLE_STAGE_ECS_PASSWORD=Abcdef12 EXAMPLE_STAGE_ECS_IMAGE_ID=img-1)
out="$(tg "$tmp/deploy/example-stage/ecs" render --json)"
if grep -q '"TF_VAR_password":"Abcdef12"' <<<"$out"; then echo "ok: tenant password mapped"; else echo "FAIL: tenant password not mapped"; fail=1; fi
if grep -q '"image_id":"img-1"' <<<"$out"; then echo "ok: tenant image id mapped"; else echo "FAIL: tenant image id not mapped"; fail=1; fi

# Positive: the oss backend keeps the s3 state identity and maps state credentials to names only the backend reads.
fresh
CASE_ENV=(EXAMPLE_STAGE_STATE_ACCESS_KEY_ID=c EXAMPLE_STAGE_STATE_SECRET_ACCESS_KEY=d)
out="$(tg "$tmp/deploy/example-stage/vpc" render --json)"
for want in 'backend \"oss\"' 'prefix              = \"example/stage/vpc\"' 'key                 = \"vpc-example-stage.tfstate\"' 'tablestore_table    = \"tflock\"' '"ALICLOUD_ACCESS_KEY_ID":"c"'; do
  if grep -qF -- "$want" <<<"$out"; then echo "ok: oss render has $want"; else echo "FAIL: oss render lacks $want"; fail=1; fi
done

# Positive: the s3, gitlab, gitea and http backends render their state identity, lock methods and credential names.
state_block() { # replaces the state = { ... } block of the temp tenant.hcl with the given settings (one per line)
  local f="$tmp/deploy/example-stage/tenant.hcl"
  sed -i '/^  state = {/,/^  }/d;$d' "$f"
  { echo "  state = {"; printf '%s\n' "$@"; echo "  }"; echo "}"; } >> "$f"
}
render_has() { # name, wanted fragments...
  local name="$1" want; shift
  for want in "$@"; do
    if grep -qF -- "$want" <<<"$out"; then echo "ok: $name render has $want"; else echo "FAIL: $name render lacks $want"; fail=1; fi
  done
}
fresh
state_block '    type = "s3"' '    bucket = "b"' '    region = "ap-southeast-5"' '    endpoint = "https://s3.example.com"'
CASE_ENV=(EXAMPLE_STAGE_STATE_ACCESS_KEY_ID=c EXAMPLE_STAGE_STATE_SECRET_ACCESS_KEY=d)
out="$(tg "$tmp/deploy/example-stage/vpc" render --json)"
render_has s3 'backend \"s3\"' 'example/stage/vpc/vpc-example-stage.tfstate' 'use_lockfile                = true' '"AWS_ACCESS_KEY_ID":"c"'

CASE_ENV=(EXAMPLE_STAGE_STATE_USERNAME=u EXAMPLE_STAGE_STATE_PASSWORD=p)
fresh
state_block '    type = "gitlab"' '    base_url = "https://git.example.com"' '    project_id = "42"'
out="$(tg "$tmp/deploy/example-stage/vpc" render --json)"
render_has gitlab 'backend \"http\"' '/api/v4/projects/42/terraform/state/example--stage--vpc--vpc-example-stage.tfstate' 'lock_method    = \"POST\"' 'unlock_method  = \"DELETE\"' '"TF_HTTP_USERNAME":"u"'
fresh
state_block '    type = "gitea"' '    base_url = "https://git.example.com"' '    owner = "ops"'
out="$(tg "$tmp/deploy/example-stage/vpc" render --json)"
render_has gitea '/api/packages/ops/terraform/state/example--stage--vpc--vpc-example-stage.tfstate' 'lock_method    = \"POST\"' 'unlock_method  = \"DELETE\"'
fresh
state_block '    type = "http"' '    base_url = "https://state.example.com"'
out="$(tg "$tmp/deploy/example-stage/vpc" render --json)"
render_has http 'address        = \"https://state.example.com/example--stage--vpc--vpc-example-stage.tfstate\"' 'lock_method    = \"LOCK\"' 'unlock_method  = \"UNLOCK\"'
CASE_ENV=()

[ "$fail" -eq 0 ] && echo "leaf guard OK"
exit "$fail"
