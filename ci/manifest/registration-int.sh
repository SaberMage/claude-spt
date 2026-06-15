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

# 3. [strings] read through the registry (base value).
base=$(spt adapter get-string claude-spt adapter_label 2>&1)
[ "$base" = "Claude Code (spt)" ] && ok "strings resolve: adapter_label (base)" || bad "base adapter_label='$base'"

# 4. Profile overlay is observable: :deep leaf-replaces the base string.
deep=$(spt adapter get-string claude-spt:deep adapter_label 2>&1)
[ "$deep" = "Claude Code (spt, deep)" ] && ok "overlay observable: :deep adapter_label differs" || bad "deep adapter_label='$deep'"

# 4b. File-backed [strings] pointer resolves to FILE CONTENTS (not the table, not raw); an inline
#     sibling still prints as-is. Proves `{ file = "skills/<x>.md" }` over adapter/strings/ (F-003).
body=$(spt adapter get-string claude-spt skills.whoami 2>&1)
case "$body" in "# /sptc:whoami"*) ok "file-backed string resolves: skills.whoami -> body" ;; *) bad "skills.whoami not resolved to file body: '$(printf %.40s "$body")'" ;; esac
inline=$(spt adapter get-string claude-spt skills.version 2>&1)
[ "$inline" = "Report the spt-core-tracked adapter/binary version-of-truth." ] && ok "inline string prints as-is: skills.version" || bad "skills.version inline='$inline'"

# 5. Soft-deregister cleanly.
rm=$(spt adapter remove claude-spt 2>&1)
list2=$(spt adapter list 2>&1)
case "$list2" in *"claude-spt"*"active"*) bad "claude-spt still active after remove" ;; *) ok "removed (soft-deregistered)" ;; esac

[ "$fail" -eq 0 ] && { echo "MANIFEST-REGISTRATION-INT OK"; exit 0; } || { echo "MANIFEST-REGISTRATION-INT FAIL"; exit 1; }
