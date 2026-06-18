#!/bin/sh
# Brand-value regression guard for the `spt endpoint run` shortcut: the manifest MUST declare
# adapter.shortcut_basename = "cc" (→ cc-<id>, the M12 cc launcher). A drift to "sptc"/"spt"/default
# is caught here, distinct from the structural manifest-schema check. (The launcher brand is
# decoupled from the plugin name `sptc`; the s/sptc/spt/ succession renames the plugin, not this.)
# Run: sh tests/manifest-shortcut.sh (exit 0 = pass).
# [unit->REQ-DIST-SHORTCUT-BASENAME]
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
MANIFEST="$ROOT/adapter/claude-spt.toml"
fail=0

# The active assignment line (not a comment): a TOML key at column 0. grep -E, exclude `#`-leading.
line=$(grep -E '^[[:space:]]*shortcut_basename[[:space:]]*=' "$MANIFEST")
if [ -z "$line" ]; then echo "FAIL no shortcut_basename assignment in manifest"; exit 1; fi

case "$line" in
  *'"cc"'*) echo "ok   shortcut_basename = \"cc\" (cc-<id> brand intact)" ;;
  *) echo "FAIL shortcut_basename is not \"cc\": $line"; fail=1 ;;
esac

# Defensive: exactly one active assignment (a stray second would make the picker value ambiguous).
n=$(grep -Ec '^[[:space:]]*shortcut_basename[[:space:]]*=' "$MANIFEST")
if [ "$n" -eq 1 ]; then echo "ok   single shortcut_basename assignment"; else echo "FAIL $n shortcut_basename assignments (want 1)"; fail=1; fi

# [unit->REQ-HAZARD-PSYCHE-PERMS-DEADLOCK]
# Non-interactive bringup: BOTH [session.self] CC spawn commands (base `claude`, the `ccs` profile)
# MUST carry --dangerously-skip-permissions. The broker spawns CC into a PTY with no operator, so an
# interactive permission prompt would deadlock the launch (docs/KNOWN-HAZARDS.md §2.2). Match the
# active `command =` lines whose value is a bare claude/ccs CC spawn — NOT `claude-spt-psyche` (the
# runner, whose own turns are asserted in tools/claude-spt-psyche unit tests).
spawn=$(grep -E '^[[:space:]]*command[[:space:]]*=[[:space:]]*"(claude|ccs)([[:space:]]|")' "$MANIFEST")
nspawn=$(printf '%s' "$spawn" | grep -c .)
if [ "$nspawn" -eq 2 ]; then echo "ok   2 [session.self] CC spawn commands (base claude + ccs)"; else echo "FAIL expected 2 CC spawn commands, found $nspawn"; fail=1; fi
nomiss=$(printf '%s\n' "$spawn" | grep -c -v -- '--dangerously-skip-permissions')
if [ "$nspawn" -gt 0 ] && [ "$nomiss" -eq 0 ]; then echo "ok   every CC spawn command carries --dangerously-skip-permissions"; else echo "FAIL a CC spawn command lacks --dangerously-skip-permissions ($nomiss without it)"; fail=1; fi

[ "$fail" -eq 0 ] && { echo "MANIFEST-SHORTCUT OK"; exit 0; } || { echo "MANIFEST-SHORTCUT FAIL"; exit 1; }
