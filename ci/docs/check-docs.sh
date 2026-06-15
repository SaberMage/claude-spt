#!/bin/sh
# Docs-drift gate: the book must BUILD, and the committed docs-site/llms.txt must MATCH a fresh
# deterministic regeneration (drift = fail). Kills doc/code drift structurally (DOCS-STRATEGY #10).
# [impl->REQ-DOCS-DRIFT]
#
# SKIPs cleanly (rc 0) when `mdbook` is absent — a fleet host without the toolchain shouldn't fail
# the gate, but the skip is ALWAYS announced (no silent cap). The llms.txt drift check runs
# regardless (it needs no toolchain).
#
# This gate is also the impl proof that docs-site/ (book.toml + src/ pages) actually builds with
# mdBook — it runs `mdbook build` against the real site. [impl->REQ-DOCS-SITE]
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
SITE="$ROOT/docs-site"
rc=0

# 1. Book builds.
if command -v mdbook >/dev/null 2>&1; then
  if ( cd "$SITE" && mdbook build >/dev/null 2>&1 ); then echo "ok   mdbook build"; else echo "FAIL: mdbook build"; rc=1; fi
else
  echo "SKIP: mdbook not on PATH — book-build check skipped (install mdBook on the fleet host)"
fi

# 2. llms.txt is not drifted from its generator.
if [ -f "$SITE/llms.txt" ]; then
  if sh "$ROOT/ci/docs/gen-llms.sh" --check | diff -u "$SITE/llms.txt" - >/dev/null 2>&1; then
    echo "ok   llms.txt in sync"
  else
    echo "FAIL: llms.txt drifted — run ci/docs/gen-llms.sh and commit the result"; rc=1
  fi
else
  echo "FAIL: docs-site/llms.txt missing — run ci/docs/gen-llms.sh"; rc=1
fi

exit "$rc"
