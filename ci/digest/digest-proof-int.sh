#!/bin/sh
# Integration proof: `spt adapter digest-proof` runs the claude-spt [digest] extractor and renders a
# non-empty digest from a real CC-shaped sample (the M10 acceptance criterion carried
# forward for spt-claude-code). [int->REQ-DIST-DIGEST-EXTRACTOR]
#
# Gated behind SPTC_ACCEPTANCE=1 (mutates the node-local adapter registry: add + soft-remove) and a
# present spt>=0.7 + a built extractor. Idempotent. Run: SPTC_ACCEPTANCE=1 sh ci/digest/digest-proof-int.sh
#
# GREEN since spt v0.7.2 (doyle's F-004 fix, release counter 14): `digest-proof --sample` now fills
# the runtime substitution keys ({id}+{session_id}, + an optional --session) matching the daemon, so
# the published-shape extractor command (`--session {session_id} --in {source}`) proofs instead of
# hard-failing {session_id}. Was F-004-blocked on <=0.7.1 (empty key map, cli.rs:5135) — the legacy
# SKIP branch below stays as a guard so an OLD binary announces the version gap rather than failing.
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
MANIFEST="$ROOT/adapter/claude-spt.toml"
SAMPLE="$ROOT/ci/digest/sample.jsonl"
RELDIR="$ROOT/tools/claude-spt-digest/target/release"

[ "${SPTC_ACCEPTANCE:-0}" = "1" ] || { echo "SKIP: set SPTC_ACCEPTANCE=1 to run (mutates the adapter registry)"; exit 0; }
command -v spt >/dev/null 2>&1 || { echo "SKIP: no spt on PATH"; exit 0; }
[ -x "$RELDIR/claude-spt-digest" ] || [ -x "$RELDIR/claude-spt-digest.exe" ] || { echo "SKIP: extractor not built (run sh ci/digest/build.sh)"; exit 0; }

trap 'spt adapter remove claude-spt >/dev/null 2>&1 || true' EXIT INT TERM
# Make the manifest's bare `claude-spt-digest` resolvable (the release dir holds the built binary).
PATH="$RELDIR:$PATH"; export PATH

spt adapter add "$MANIFEST" >/dev/null 2>&1 || { echo "FAIL: spt adapter add"; exit 1; }

out=$(spt adapter digest-proof claude-spt --sample "$SAMPLE" 2>&1)
case "$out" in
  *DIGEST_PROOF_OK*)
    echo "ok  digest-proof: DIGEST_PROOF_OK"
    printf '%s\n' "$out" | grep -E 'parsed|dropped' | sed 's/^/    /'
    echo "DIGEST-PROOF-INT OK"; exit 0 ;;
  *"no value for substitution key {session_id}"*)
    echo "SKIP: spt < v0.7.2 — digest-proof --sample doesn't fill {session_id} (pre-F-004-fix binary)."
    echo "      upgrade to spt >= 0.7.2 (release counter 14) to run this int. Extractor itself: cargo tests green."
    exit 0 ;;
  *)
    echo "FAIL: unexpected digest-proof output:"; printf '%s\n' "$out"; exit 1 ;;
esac
