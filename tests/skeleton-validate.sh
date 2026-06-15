#!/bin/sh
# Unit tests for the cplugs skeleton validator: it must PASS the real skeleton and FAIL on tampered
# copies (leaked runtime state / planted binary / missing SKILL.md) — proving the gate catches
# real breakage, not just green-on-green. Run: sh tests/skeleton-validate.sh  (exit 0 = pass).
# [unit->REQ-DIST-PLUGIN-SKELETON]
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
VALIDATE="$ROOT/ci/publish/validate-skeleton.sh"
fail=0

# 1. Real skeleton is installable.
if sh "$VALIDATE" "$ROOT/plugin/sptc" >/dev/null 2>&1; then echo "ok   real skeleton validates"; else echo "FAIL real skeleton rejected"; sh "$VALIDATE" "$ROOT/plugin/sptc"; fail=1; fi

# Build a clean fixture copy we can tamper.
work=$(mktemp -d) || { echo "FAIL mktemp"; exit 1; }
trap 'rm -rf "$work"' EXIT INT TERM
sk="$work/sptc"
mkdir -p "$sk"
cp -r "$ROOT/plugin/sptc/.claude-plugin" "$sk/"
cp -r "$ROOT/plugin/sptc/hooks" "$sk/"
cp -r "$ROOT/plugin/sptc/skills" "$sk/"
cp "$ROOT/plugin/sptc/bootstrap.sh" "$sk/" 2>/dev/null || true

# Sanity: the clean copy validates (else later negatives are meaningless).
if sh "$VALIDATE" "$sk" >/dev/null 2>&1; then echo "ok   clean fixture validates"; else echo "FAIL clean fixture rejected"; fail=1; fi

# 2. Runtime state leaked INTO a published path (hooks/) must FAIL — this is the real publish leak
#    (state inside the subset that package-skeleton.sh would copy to the marketplace). State in a
#    non-published dir like `.claude/` is intentionally NOT a finding: the packager never copies it.
printf '{"last_used":"perri"}\n' > "$sk/hooks/LIVE_AGENT_IDS.json"
if sh "$VALIDATE" "$sk" >/dev/null 2>&1; then echo "FAIL leaked LIVE_AGENT_IDS.json not caught"; fail=1; else echo "ok   catches runtime state in published path"; fi
rm -f "$sk/hooks/LIVE_AGENT_IDS.json"

# 3. Planted binary must FAIL.
printf 'MZ\0' > "$sk/skills/rogue.exe"
if sh "$VALIDATE" "$sk" >/dev/null 2>&1; then echo "FAIL planted .exe not caught"; fail=1; else echo "ok   catches planted binary"; fi
rm -f "$sk/skills/rogue.exe"

# 4. Missing SKILL.md must FAIL.
victim=$(find "$sk/skills" -name SKILL.md | head -n1)
mv "$victim" "$victim.bak"
if sh "$VALIDATE" "$sk" >/dev/null 2>&1; then echo "FAIL missing SKILL.md not caught"; fail=1; else echo "ok   catches missing SKILL.md"; fi
mv "$victim.bak" "$victim"

# 5. Wrong plugin name must FAIL.
sed 's/"name": "sptc"/"name": "wrong"/' "$sk/.claude-plugin/plugin.json" > "$sk/.claude-plugin/plugin.json.tmp" && mv "$sk/.claude-plugin/plugin.json.tmp" "$sk/.claude-plugin/plugin.json"
if sh "$VALIDATE" "$sk" >/dev/null 2>&1; then echo "FAIL wrong plugin name not caught"; fail=1; else echo "ok   catches wrong plugin name"; fi

[ "$fail" -eq 0 ] && { echo "SKELETON-VALIDATE OK"; exit 0; } || { echo "SKELETON-VALIDATE FAIL"; exit 1; }
