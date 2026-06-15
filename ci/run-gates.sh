#!/bin/sh
# Deterministic CI gates for spt-claude-code — each a binary pass/fail, no model in the loop.
# Runnable by hand on any fleet host: this IS the manual fallback. [impl->REQ-CI-GATES]
# [impl->REQ-CI-MANUAL]
# Gates whose artifact doesn't exist yet SKIP with a logged note (no silent caps — a skip is
# always announced so "green" never hides un-run coverage).
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 2
rc=0
gate() { printf '\n=== GATE: %s ===\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; rc=1; }

gate "shell-syntax (sh -n)"
for f in $(find plugin tests ci -name '*.sh' 2>/dev/null | sort); do
  if sh -n "$f"; then printf 'ok  %s\n' "$f"; else fail "syntax: $f"; fi
done

gate "unit tests (tests/*.sh)"
for t in tests/*.sh; do
  [ -e "$t" ] || continue
  if sh "$t" >/dev/null 2>&1; then printf 'ok  %s\n' "$t"; else fail "unit: $t"; sh "$t" || true; fi
done

gate "traceable-reqs check (requirement coverage)"
if command -v traceable-reqs >/dev/null 2>&1; then
  if traceable-reqs check >/dev/null 2>&1; then echo "ok  coverage green"; else fail "traceable-reqs check"; traceable-reqs check || true; fi
else
  echo "SKIP: traceable-reqs not on PATH (install per docs/TRACEABILITY.md)"
fi

gate "skeleton-validate (cplugs installability)"
if [ -x "$ROOT/ci/publish/validate-skeleton.sh" ] || [ -f "$ROOT/ci/publish/validate-skeleton.sh" ]; then
  if sh "$ROOT/ci/publish/validate-skeleton.sh" >/dev/null 2>&1; then echo "ok  skeleton installable"; else fail "skeleton-validate"; sh "$ROOT/ci/publish/validate-skeleton.sh" || true; fi
else
  echo "SKIP: no skeleton validator yet"
fi

gate "manifest-schema"
if [ -f "$ROOT/ci/manifest/check-manifest.sh" ]; then
  if sh "$ROOT/ci/manifest/check-manifest.sh"; then :; else fail "manifest-schema"; fi
else
  echo "SKIP: no adapter manifest yet — activates when the CC adapter manifest lands"
fi

gate "docs-drift"
if [ -f "$ROOT/ci/docs/check-docs.sh" ]; then
  if sh "$ROOT/ci/docs/check-docs.sh"; then :; else fail "docs-drift"; fi
else
  echo "SKIP: no docs check yet"
fi

printf '\n=== RESULT: %s ===\n' "$([ "$rc" -eq 0 ] && echo PASS || echo FAIL)"
exit "$rc"
