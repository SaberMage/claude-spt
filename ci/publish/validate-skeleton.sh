#!/bin/sh
# Validate the sptc cplugs SKELETON is a coherent, installable artifact carrying ONLY the skeleton
# subset — no runtime state, no binary, no adapter manifest (those ride the spt-core registry, never
# cplugs; see docs/RELEASE-RUNBOOK.md). Deterministic, binary pass/fail. [impl->REQ-DIST-PLUGIN-SKELETON]
#
# Usage: validate-skeleton.sh [plugin-dir]   (default: <repo>/plugin/sptc). Exit 0 = installable.
set -u
HERE=$(CDPATH= cd "$(dirname "$0")" && pwd)
ROOT=$(CDPATH= cd "$HERE/../.." && pwd)
PLUGIN="${1:-$ROOT/plugin/sptc}"
rc=0
bad() { printf 'FAIL: %s\n' "$1"; rc=1; }
ok()  { printf 'ok   %s\n' "$1"; }

[ -d "$PLUGIN" ] || { echo "FATAL: no plugin dir at $PLUGIN"; exit 2; }

# A minimal JSON well-formedness check without a hard jq dependency: prefer jq, else python, else
# a balanced-brace heuristic. Returns 0 if $1 parses / looks well-formed.
json_ok() {
  if command -v jq >/dev/null 2>&1; then jq -e . "$1" >/dev/null 2>&1; return $?; fi
  if command -v python3 >/dev/null 2>&1; then python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$1" >/dev/null 2>&1; return $?; fi
  # Heuristic fallback: non-empty, starts with { , balanced braces.
  head -c1 "$1" | grep -q '{' || return 1
  awk '{n+=gsub(/{/,"{"); n-=gsub(/}/,"}")} END{exit (n==0)?0:1}' "$1"
}
# Extract a flat top-level "key":"value" string (same shape _common.sh uses).
jval() { sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$1" | head -n1; }

# ── plugin.json ──────────────────────────────────────────────────────────────
PJ="$PLUGIN/.claude-plugin/plugin.json"
if [ -f "$PJ" ] && json_ok "$PJ"; then ok "plugin.json valid JSON"; else bad "plugin.json missing/invalid ($PJ)"; fi
if [ -f "$PJ" ]; then
  [ "$(jval "$PJ" name)" = "sptc" ] && ok "plugin.json name=sptc" || bad "plugin.json name != sptc (got '$(jval "$PJ" name)')"
  [ -n "$(jval "$PJ" version)" ] && ok "plugin.json has version" || bad "plugin.json missing version"
  [ -n "$(jval "$PJ" description)" ] && ok "plugin.json has description" || bad "plugin.json missing description"
fi

# ── hooks.json + every referenced wrapper exists ─────────────────────────────
HJ="$PLUGIN/hooks/hooks.json"
if [ -f "$HJ" ] && json_ok "$HJ"; then
  ok "hooks.json valid JSON"
  # Pull each hooks/<name>.sh token referenced in commands; assert the file exists.
  refs=$(grep -o 'hooks/[A-Za-z0-9_-]*\.sh' "$HJ" | sort -u)
  for r in $refs; do
    if [ -f "$PLUGIN/$r" ]; then ok "hook wrapper present: $r"; else bad "hooks.json references missing wrapper: $r"; fi
  done
else
  bad "hooks.json missing/invalid ($HJ)"
fi

# ── every skill dir has a SKILL.md ───────────────────────────────────────────
if [ -d "$PLUGIN/skills" ]; then
  for d in "$PLUGIN"/skills/*/; do
    [ -e "$d" ] || continue
    if [ -f "${d}SKILL.md" ]; then ok "skill ok: $(basename "$d")"; else bad "skill missing SKILL.md: $(basename "$d")"; fi
  done
else
  bad "no skills/ dir"
fi

# ── skeleton-subset invariant: NO runtime state / binary / manifest in the PUBLISHED surface ──
# [impl->REQ-DIST-PLUGIN-SKELETON]
# Scan only the subset that actually gets published (what package-skeleton.sh copies) — never the
# whole plugin dir, so gitignored dev-tree runtime noise (e.g. a live perch's `.claude/`, which the
# packager never copies) doesn't false-fail the gate. A leak here means a non-skeleton file landed
# INSIDE a published path (skills/, hooks/, plugin.json, bootstrap) — that ships, so it must fail.
SUBSET_PATHS="$PLUGIN/.claude-plugin/plugin.json $PLUGIN/hooks $PLUGIN/skills $PLUGIN/bootstrap.sh $PLUGIN/bootstrap.ps1"
scan=""
for p in $SUBSET_PATHS; do [ -e "$p" ] && scan="$scan $p"; done
leaks=$(find $scan -type f \( \
     -name 'LIVE_AGENT_IDS.json' \
  -o -name '*-commune.md' \
  -o -name '*-signoff.md' \
  -o -name 'cc' -o -name 'cc-*' -o -name 'cc.bat' -o -name 'cc.sh' \
  -o -name '*.exe' -o -name '*.bin' -o -name '*.dll' \
  -o -name 'manifest.json' \) 2>/dev/null)
if [ -z "$leaks" ]; then
  ok "published surface clean (no runtime/binary/manifest leak)"
else
  printf 'FAIL: non-skeleton files in the published surface (runtime state / binary / manifest belong in the spt-core registry, not cplugs):\n%s\n' "$leaks"
  rc=1
fi

printf '\n=== SKELETON: %s ===\n' "$([ "$rc" -eq 0 ] && echo INSTALLABLE || echo INVALID)"
exit "$rc"
