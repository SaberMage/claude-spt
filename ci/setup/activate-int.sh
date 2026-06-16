#!/bin/sh
# Integration proof for the /sptc:setup ACTIVATION bridge (F-005): binary-present is NOT a no-op —
# when the adapter is `deregistered`, setup RE-ACTIVATES it. This encodes, as deterministic CLI
# assertions on a real spt-core (>= v0.7.0), the exact deregistered->active transition the setup
# skill body performs in local-dev (file-form) mode: probe `adapter list`; if deregistered ->
# `adapter add <manifest>` -> verify active + shipped profile resolves. The LLM is never in the
# loop. [int->REQ-SETUP-ACTIVATE]
#
# Mutates the node-local adapter registry (add/remove), so it is gated behind SPTC_ACCEPTANCE=1 and a
# present spt>=0.7.0 — never runs in the default `tests/*.sh` unit sweep. Idempotent: removes what it
# adds. Run: SPTC_ACCEPTANCE=1 sh ci/setup/activate-int.sh   (exit 0 = pass).
#
# NOTE: this is the LOCAL file-form (dev) activation path. The END-USER `--release` acquisition leg
# is proven separately by ci/publish/release-acquire-int.sh (REQ-DIST-ADAPTER-RELEASE).
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
MANIFEST="$ROOT/adapter/claude-spt.toml"

if [ "${SPTC_ACCEPTANCE:-0}" != "1" ]; then echo "SKIP: set SPTC_ACCEPTANCE=1 to run (mutates the adapter registry)"; exit 0; fi
command -v spt >/dev/null 2>&1 || { echo "SKIP: no spt on PATH"; exit 0; }
ver=$(spt --version 2>/dev/null | awk '{print $NF}')
case "$ver" in
  0.6.*|0.5.*|0.4.*|0.3.*|0.2.*|0.1.*|0.0.*) echo "SKIP: spt $ver < 0.7.0 (adapter add is v0.7.0)"; exit 0 ;;
esac
[ -f "$MANIFEST" ] || { echo "SKIP: no manifest at $MANIFEST"; exit 0; }

fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
# Clean up registry residue however we exit (leave no claude-spt registration behind).
trap 'spt adapter remove claude-spt >/dev/null 2>&1 || true' EXIT INT TERM

# 0. Seed a registration, then soft-remove it to reach the F-005 trigger state: a `deregistered`
#    adapter (the residue a prior install/uninstall leaves — binary present, adapter NOT active).
spt adapter add "$MANIFEST" >/dev/null 2>&1
spt adapter remove claude-spt >/dev/null 2>&1
pre=$(spt adapter list 2>&1)
preline=$(printf '%s\n' "$pre" | grep '^claude-spt:')
case "$preline" in
  *deregistered*) ok "precondition: claude-spt is deregistered (F-005 trigger state)" ;;
  "")             ok "precondition: claude-spt absent (also a non-active start state)" ;;
  *active*)       bad "precondition not reached: claude-spt still active before re-activate ($preline)" ;;
  *)              ok "precondition: claude-spt not active ($preline)" ;;
esac

# 1. RE-ACTIVATE — the setup bridge step: `adapter add` the local manifest.
out=$(spt adapter add "$MANIFEST" 2>&1)
case "$out" in *registered*) ok "re-activate: adapter add registered the manifest" ;; *) bad "adapter add rejected: $out" ;; esac

# 2. Verify active — deregistered -> active is the transition setup guarantees.
post=$(spt adapter list 2>&1)
postline=$(printf '%s\n' "$post" | grep '^claude-spt:')
case "$postline" in *active*) ok "verified: claude-spt is now active" ;; *) bad "claude-spt not active after re-activate ($postline)" ;; esac

# 3. Profiles/strings went live with activation (the point of activating, not just registering).
case "$post" in *claude-spt:deep*) ok "shipped profile resolves post-activate: claude-spt:deep" ;; *) bad "deep profile not resolved post-activate" ;; esac
lbl=$(spt adapter get-string claude-spt adapter_label 2>&1)
[ "$lbl" = "Claude Code (spt)" ] && ok "strings live post-activate: adapter_label" || bad "adapter_label='$lbl'"

[ "$fail" -eq 0 ] && { echo "SETUP-ACTIVATE-INT OK"; exit 0; } || { echo "SETUP-ACTIVATE-INT FAIL"; exit 1; }
