#!/bin/sh
# Unit tests for the docs generator: deterministic output + full SUMMARY coverage. No mdbook needed.
# Run: sh tests/docs-gen.sh   (exit 0 = pass). [unit->REQ-DOCS-DRIFT]
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
GEN="$ROOT/ci/docs/gen-llms.sh"
SUMMARY="$ROOT/docs-site/src/SUMMARY.md"
fail=0

# 1. Deterministic: two regenerations are byte-identical.
a=$(sh "$GEN" --check); b=$(sh "$GEN" --check)
[ "$a" = "$b" ] && echo "ok   generator deterministic" || { echo "FAIL non-deterministic"; fail=1; }

# 2. Coverage: every page linked in SUMMARY.md appears in the generated index (as .html).
miss=0
for rel in $(grep -o '(\./[A-Za-z0-9_./-]*\.md)' "$SUMMARY" | sed 's/^(\.\///; s/)$//'); do
  html=$(printf '%s' "$rel" | sed 's/\.md$/.html/')
  if printf '%s\n' "$a" | grep -q "($html)"; then :; else echo "FAIL uncovered page: $rel"; miss=1; fi
done
[ "$miss" -eq 0 ] && echo "ok   all SUMMARY pages covered" || fail=1

# 3. Shape: starts with the H1 title and the blockquote summary (llms.txt convention).
printf '%s\n' "$a" | head -n1 | grep -q '^# claude-spt' && echo "ok   has H1 title" || { echo "FAIL missing H1"; fail=1; }
printf '%s\n' "$a" | grep -q '^> ' && echo "ok   has summary blockquote" || { echo "FAIL missing summary"; fail=1; }

# 4. Drift gate is wired and valid shell.
sh -n "$ROOT/ci/docs/check-docs.sh" && echo "ok   check-docs valid shell" || { echo "FAIL check-docs syntax"; fail=1; }

[ "$fail" -eq 0 ] && { echo "DOCS-GEN OK"; exit 0; } || { echo "DOCS-GEN FAIL"; exit 1; }
