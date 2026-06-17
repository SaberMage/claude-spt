#!/bin/sh
# Integration proof for the claude-spt adapter manifest against a REAL spt-core (>= v0.7.0): the
# 2nd validation layer beyond JSON Schema — spt-core's `spt adapter add` cross-field registration —
# accepts the manifest, the shipped profile resolves, [strings] read through the registry, and the
# profile overlay is observable (base vs :deep differ). This is the v1 acceptance proof for the
# adapter manifest (LLM never in the loop; pure CLI assertions). [int->REQ-DIST-MANIFEST-SCHEMA]
#
# Mutates the node-local adapter registry (add + soft-remove), so it is gated behind SPTC_ACCEPTANCE=1
# and a present spt>=0.7.0 — never runs in the default `tests/*.sh` unit sweep. Idempotent: removes
# what it adds. Run: SPTC_ACCEPTANCE=1 sh ci/manifest/registration-int.sh   (exit 0 = pass).
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
MANIFEST="$ROOT/adapter/claude-spt.toml"

if [ "${SPTC_ACCEPTANCE:-0}" != "1" ]; then echo "SKIP: set SPTC_ACCEPTANCE=1 to run (mutates the adapter registry)"; exit 0; fi
command -v spt >/dev/null 2>&1 || { echo "SKIP: no spt on PATH"; exit 0; }
ver=$(spt --version 2>/dev/null | awk '{print $NF}')
case "$ver" in
  0.6.*|0.5.*|0.4.*|0.3.*|0.2.*|0.1.*|0.0.*) echo "SKIP: spt $ver < 0.7.0 (shortcut_basename + adapter add are v0.7.0)"; exit 0 ;;
esac

fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
# Clean up registry residue however we exit.
trap 'spt adapter remove claude-spt >/dev/null 2>&1 || true' EXIT INT TERM

# 1. Registration cross-field validation accepts the manifest.
out=$(spt adapter add "$MANIFEST" 2>&1)
case "$out" in *registered*) ok "spt adapter add: registered" ;; *) bad "adapter add rejected: $out" ;; esac

# 2. Listed, with the shipped profile resolved as a composite option.
list=$(spt adapter list 2>&1)
case "$list" in *claude-spt*) ok "listed: claude-spt active" ;; *) bad "claude-spt not listed" ;; esac
case "$list" in *claude-spt:deep*) ok "shipped profile resolves: claude-spt:deep" ;; *) bad "deep profile not resolved" ;; esac
# NOTE: there is no `:live` profile (Option A, PREP-4) — base claude-spt is live-capable
# ([session.psyche_init] in base); the LiveAgent capability is asserted via `spt api capability` at
# step 4d below, not a composite resolve.
# The ccs overlay (:ccs leaf-replaces [session.self].command -> `ccs`, a drop-in for `claude`) —
# the LOCKED-ADD ccs profile template (REQ-CCS-PROFILES; validated vs sister project claude_skill_owl).
case "$list" in *claude-spt:ccs*) ok "shipped profile resolves: claude-spt:ccs (ccs overlay)" ;; *) bad "ccs profile not resolved" ;; esac

# 3. [strings] read through the registry (base value).
base=$(spt adapter get-string claude-spt adapter_label 2>&1)
[ "$base" = "Claude Code (spt)" ] && ok "strings resolve: adapter_label (base)" || bad "base adapter_label='$base'"

# 4. Profile overlay is observable: :deep leaf-replaces the base string.
deep=$(spt adapter get-string claude-spt:deep adapter_label 2>&1)
[ "$deep" = "Claude Code (spt, deep)" ] && ok "overlay observable: :deep adapter_label differs" || bad "deep adapter_label='$deep'"
# :ccs overlay observable the same way (leaf-replaced adapter_label). [int->REQ-CCS-PROFILES]
ccs=$(spt adapter get-string claude-spt:ccs adapter_label 2>&1)
[ "$ccs" = "Claude Code (spt, ccs)" ] && ok "overlay observable: :ccs adapter_label differs" || bad "ccs adapter_label='$ccs'"

# 4b. File-backed [strings] pointer resolves to FILE CONTENTS (not the table, not raw); an inline
#     sibling still prints as-is. Proves `{ file = "skills/<x>.md" }` over adapter/strings/ (F-003).
body=$(spt adapter get-string claude-spt skills.ready 2>&1)
case "$body" in "# /sptc:ready"*) ok "file-backed string resolves: skills.ready -> body" ;; *) bad "skills.ready not resolved to file body: '$(printf %.40s "$body")'" ;; esac
# Newly file-backed skills (commune = file-drop body; force-stop = endpoint shutdown body).
cbody=$(spt adapter get-string claude-spt skills.commune 2>&1)
case "$cbody" in "# /sptc:commune"*) ok "file-backed string resolves: skills.commune -> body" ;; *) bad "skills.commune not resolved to file body: '$(printf %.40s "$cbody")'" ;; esac
fbody=$(spt adapter get-string claude-spt "skills.force-stop" 2>&1)
case "$fbody" in "# /sptc:force-stop"*) ok "file-backed string resolves: skills.force-stop -> body" ;; *) bad "skills.force-stop not resolved to file body: '$(printf %.40s "$fbody")'" ;; esac
# `live` is file-backed too (the LiveAgent bringup body — base [session.psyche_init] + bare
# `api listen`; REQ-SKILL-LIVE).
lbody=$(spt adapter get-string claude-spt skills.live 2>&1)
case "$lbody" in "# /sptc:live"*) ok "file-backed string resolves: skills.live -> body" ;; *) bad "skills.live not resolved to file body: '$(printf %.40s "$lbody")'" ;; esac
# subnet (LOCKED-ADD cross-machine membership skill — wraps `spt subnet`). [int->REQ-SKILL-SUBNET]
sbody=$(spt adapter get-string claude-spt skills.subnet 2>&1)
case "$sbody" in "# /sptc:subnet"*) ok "file-backed string resolves: skills.subnet -> body" ;; *) bad "skills.subnet not resolved to file body: '$(printf %.40s "$sbody")'" ;; esac

# 4c. UPS skill-injection end-to-end: the hook helper resolves a /sptc:<skill> prompt to the wrapped
#     operative body via get-string (REQ-UPS-INJECTION impl, on the registered adapter).
( . "$ROOT/plugin/sptc/hooks/_common.sh"
  inj=$(sptc_inject_skill "$(sptc_skill_key '/sptc:ready listen up')")
  case "$inj" in
    '<sptc_skill name="ready">'*'# /sptc:ready'*'</sptc_skill>'*) exit 0 ;;
    *) printf 'inject got: %.60s\n' "$inj"; exit 1 ;;
  esac ) && ok "UPS skill-injection: /sptc:ready -> wrapped body" || bad "skill-injection did not emit wrapped body"

# 4d. The spt-hosted bringup blocks ([session.self] + [env.SPT_ENDPOINT_ID]) cross-field-validate:
#     `adapter add` (step 1) is manifest-first ("an invalid manifest registers nothing"), so the
#     manifest carrying these blocks registering at all proves spt-core accepted their shape. Confirm
#     the registered adapter advertises a hostable harness — the thing `spt endpoint run` spawns via
#     [session.self] (the M12 cc-launcher target). [int->REQ-DIST-MANIFEST-SCHEMA]
cap=$(spt api --adapter claude-spt --manifest "$MANIFEST" capability 2>&1)
case "$cap" in *LiveAgent*) ok "bringup blocks accepted; capability reports hostable harness" ;; *) bad "capability missing LiveAgent: $cap" ;; esac

# 5. Soft-deregister cleanly.
rm=$(spt adapter remove claude-spt 2>&1)
list2=$(spt adapter list 2>&1)
case "$list2" in *"claude-spt"*"active"*) bad "claude-spt still active after remove" ;; *) ok "removed (soft-deregistered)" ;; esac

[ "$fail" -eq 0 ] && { echo "MANIFEST-REGISTRATION-INT OK"; exit 0; } || { echo "MANIFEST-REGISTRATION-INT FAIL"; exit 1; }
