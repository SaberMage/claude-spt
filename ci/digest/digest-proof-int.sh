#!/bin/sh
# Integration proof: `spt adapter digest-proof` runs the claude-spt [digest] extractor under the
# v0.19.0 FETCHER strategy and renders a non-empty digest from a real CC-shaped sample (the M10
# acceptance criterion carried forward). [int->REQ-DIST-DIGEST-EXTRACTOR]
# Also the consolidation int (ADR-0006/U2): --dir resolves the bare `claude-spt` binary and the
# manifest extractor command `claude-spt digest …` runs its `digest` subcommand end-to-end through
# real spt — proving the merged binary's digest seam still works. [int->REQ-DIST-BINARY-CONSOLIDATE]
#
# FETCHER shape (v0.10.0, spt-core v0.19.0): the manifest extractor is
#   `claude-spt digest --session {session_id} --config-dir {CLAUDE_CONFIG_DIR}`
# — the extractor LOCATES the transcript itself (no spt-core pre-read, no `source`, no --sample
# pipe). So this int builds a THROWAWAY config root shaped like CC's partitioned layout
# (<root>/projects/<slug>/<session_id>.jsonl from the checked-in sample), points the proof at it
# via the CLAUDE_CONFIG_DIR env (empirically proven 2026-07-01: digest-proof resolves the
# {CLAUDE_CONFIG_DIR} read-var from the invoking environment, value-fallback ~/.claude when absent
# — the same capture semantics as the daemon's bind-time read_env), pins {session_id} with
# --session, and asserts the located-and-extracted digest renders. This exercises the WHOLE
# fetcher chain: read-var capture → fill → extractor locate → NDJSON records → rendered digest.
# [int->REQ-DIST-DIGEST-FETCHER]
#
# Uses the v0.13.2 `--dir`/`--manifest` override (F-011 closed, W5) to proof the DEV extractor
# straight from its build dir against the bare-file manifest — NO registry mutation, read-only,
# so NO SPTC_ACCEPTANCE gate. Needs spt >= 0.19.0 (the fetcher strategy + read-var fill; an older
# binary rejects/misruns strategy="fetcher") + a built extractor. Idempotent.
# Run: sh ci/digest/digest-proof-int.sh   (exit 0 = pass).
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
MANIFEST="$ROOT/adapter/claude-spt.toml"
SAMPLE="$ROOT/ci/digest/sample.jsonl"
RELDIR="$ROOT/tools/claude-spt/target/release"   # consolidated binary; the `digest` subcommand is the extractor (ADR-0006/U2)

command -v spt >/dev/null 2>&1 || { echo "SKIP: no spt on PATH"; exit 0; }

# The fetcher strategy + {CLAUDE_CONFIG_DIR} read-var fill land in spt-core v0.19.0 — version-gate.
ver=$(spt --version 2>/dev/null | sed -E 's/^spt //')
case "$ver" in
  0.19.*|0.[2-9][0-9].*|[1-9]*.*) : ;;  # >= 0.19.0
  *) echo "SKIP: spt $ver < 0.19.0 (no [digest] fetcher strategy). Extractor itself: cargo tests green."; exit 0 ;;
esac

[ -x "$RELDIR/claude-spt" ] || [ -x "$RELDIR/claude-spt.exe" ] || { echo "SKIP: extractor not built (run sh ci/digest/build.sh)"; exit 0; }

# Throwaway CC-shaped config root: <root>/projects/<slug>/<session_id>.jsonl. The slug subdir is
# deliberately arbitrary — the extractor's locate must find the session file WITHIN the tree
# (the cwd-slug is CC-internal; the locate is the fetcher's whole point).
SESSION="sptc-fetcher-int-$$"
CFGROOT="${TMPDIR:-/tmp}/sptc-digest-int-$$"
mkdir -p "$CFGROOT/projects/C--some-project-slug"
cp "$SAMPLE" "$CFGROOT/projects/C--some-project-slug/$SESSION.jsonl"
trap 'rm -rf "$CFGROOT"' EXIT

out=$(CLAUDE_CONFIG_DIR="$CFGROOT" spt adapter digest-proof claude-spt \
        --session "$SESSION" --manifest "$MANIFEST" --dir "$RELDIR" 2>&1)
case "$out" in
  *DIGEST_PROOF_OK*)
    echo "ok  digest-proof (fetcher locate): DIGEST_PROOF_OK"
    printf '%s\n' "$out" | grep -E 'parsed|dropped' | sed 's/^/    /'
    echo "DIGEST-PROOF-INT OK"; exit 0 ;;
  *DIGEST_PROOF_EMPTY*)
    echo "FAIL: fetcher locate found nothing — the {CLAUDE_CONFIG_DIR} capture or the extractor's"
    echo "      locate chain regressed (root: $CFGROOT, session: $SESSION):"
    printf '%s\n' "$out"; exit 1 ;;
  *)
    echo "FAIL: unexpected digest-proof output:"; printf '%s\n' "$out"; exit 1 ;;
esac
