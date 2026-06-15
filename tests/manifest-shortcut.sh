#!/bin/sh
# Brand-value regression guard for the `spt endpoint run` shortcut: the manifest MUST declare
# adapter.shortcut_basename = "sptc" (→ sptc-<id>). This is the s/sptc/spt/ succession seam
# (ADR-0001) — a premature flip to "spt", or a drift to "cc"/default, is caught here, distinct
# from the structural manifest-schema check. Run: sh tests/manifest-shortcut.sh (exit 0 = pass).
# [unit->REQ-DIST-SHORTCUT-BASENAME]
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
MANIFEST="$ROOT/adapter/claude-spt.toml"
fail=0

# The active assignment line (not a comment): a TOML key at column 0. grep -E, exclude `#`-leading.
line=$(grep -E '^[[:space:]]*shortcut_basename[[:space:]]*=' "$MANIFEST")
if [ -z "$line" ]; then echo "FAIL no shortcut_basename assignment in manifest"; exit 1; fi

case "$line" in
  *'"sptc"'*) echo "ok   shortcut_basename = \"sptc\" (sptc-<id> brand intact)" ;;
  *) echo "FAIL shortcut_basename is not \"sptc\": $line"; fail=1 ;;
esac

# Defensive: exactly one active assignment (a stray second would make the picker value ambiguous).
n=$(grep -Ec '^[[:space:]]*shortcut_basename[[:space:]]*=' "$MANIFEST")
if [ "$n" -eq 1 ]; then echo "ok   single shortcut_basename assignment"; else echo "FAIL $n shortcut_basename assignments (want 1)"; fail=1; fi

[ "$fail" -eq 0 ] && { echo "MANIFEST-SHORTCUT OK"; exit 0; } || { echo "MANIFEST-SHORTCUT FAIL"; exit 1; }
