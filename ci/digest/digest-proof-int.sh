#!/bin/sh
# Integration proof: `spt adapter digest-proof` runs the claude-spt [digest] extractor and renders a
# non-empty digest from a real CC-shaped sample (the M10 acceptance criterion carried
# forward for spt-claude-code). [int->REQ-DIST-DIGEST-EXTRACTOR]
# Also the consolidation int (ADR-0006/U2): --dir resolves the bare `claude-spt` binary and the
# manifest extractor command `claude-spt digest …` runs its `digest` subcommand end-to-end through
# real spt — proving the merged binary's digest seam still works. [int->REQ-DIST-BINARY-CONSOLIDATE]
#
# Uses the v0.13.2 `--dir`/`--manifest` override (F-011 closed, W5) to proof the DEV extractor
# straight from its build dir against the bare-file manifest: --dir resolves the binary (before PATH)
# exactly as the daemon does, --manifest pins the bare-file manifest. NO registry mutation — the prior
# form `adapter add`/`adapter remove claude-spt` soft-removed the REAL registered claude-spt on
# cleanup, AND the bare-file add went stale on spt 0.13.x (a gh_release manifest registers
# GhReleaseManaged but unextracted -> F-011 manifest-not-present -> digest-proof failed). Read-only
# now, so NO SPTC_ACCEPTANCE gate. Needs spt >= 0.13.2 (the --dir/--manifest options) + a built
# extractor. Idempotent. Run: sh ci/digest/digest-proof-int.sh   (exit 0 = pass).
#
# GREEN since spt v0.7.2 (doyle's F-004 fix): digest-proof fills the runtime substitution keys
# ({id}+{session_id}, + optional --session) matching the daemon, so the published-shape extractor
# command (`--session {session_id} --in {source}`) proofs instead of hard-failing {session_id}.
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
MANIFEST="$ROOT/adapter/claude-spt.toml"
SAMPLE="$ROOT/ci/digest/sample.jsonl"
RELDIR="$ROOT/tools/claude-spt/target/release"   # consolidated binary; the `digest` subcommand is the extractor (ADR-0006/U2)

command -v spt >/dev/null 2>&1 || { echo "SKIP: no spt on PATH"; exit 0; }

# --dir/--manifest landed in spt v0.13.2 — capability-detect rather than version-parse.
if ! spt adapter digest-proof --help 2>&1 | grep -q -- '--dir'; then
  echo "SKIP: spt 'adapter digest-proof' has no --dir/--manifest (needs v0.13.2). Extractor itself: cargo tests green."
  exit 0
fi

[ -x "$RELDIR/claude-spt" ] || [ -x "$RELDIR/claude-spt.exe" ] || { echo "SKIP: extractor not built (run sh ci/digest/build.sh)"; exit 0; }

# Proof the dev extractor in-place: --dir resolves the binary (before PATH) like the daemon, --manifest
# pins the bare-file gh_release manifest — no extracted install, no registry touch.
out=$(spt adapter digest-proof claude-spt --sample "$SAMPLE" --manifest "$MANIFEST" --dir "$RELDIR" 2>&1)
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
