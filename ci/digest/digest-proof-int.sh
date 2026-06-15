#!/bin/sh
# Integration proof: `spt adapter digest-proof` runs the claude-spt [digest] extractor and renders a
# non-empty digest from a real CC-shaped sample (ADR-0019 — the M10 acceptance criterion carried
# forward for spt-claude-code). [int->REQ-DIST-DIGEST-EXTRACTOR]
#
# Gated behind SPTC_ACCEPTANCE=1 (mutates the node-local adapter registry: add + soft-remove) and a
# present spt>=0.7 + a built extractor. Idempotent. Run: SPTC_ACCEPTANCE=1 sh ci/digest/digest-proof-int.sh
#
# KNOWN-BLOCKED (F-004, doyle-confirmed spt-core impl bug, fix in progress): the production-correct
# extractor command references {session_id} (CC's cwd-slug forces projects-root + a --session locate
# the extractor resolves itself). `digest-proof --sample` passes an EMPTY substitution-key map
# (cli.rs:5135) vs the runtime daemon which fills {id}+{session_id} — so it hard-fails {session_id}.
# Until doyle's fix lands (digest-proof will fill the runtime keys), this SKIPs on that exact error.
# The extractor itself is proven: cargo tests (ci/digest/build.sh) + a source-only digest-proof run
# returned DIGEST_PROOF_OK (5 parsed / 0 dropped, correct render — F-004 "Variant A").
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
    echo "SKIP: blocked on F-004 — digest-proof --sample does not yet fill {session_id} (doyle's spt-core fix pending)."
    echo "      extractor proven via cargo tests + source-only Variant A (DIGEST_PROOF_OK). Flip on the carrying release."
    exit 0 ;;
  *)
    echo "FAIL: unexpected digest-proof output:"; printf '%s\n' "$out"; exit 1 ;;
esac
