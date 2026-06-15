#!/bin/sh
# Stage the sptc cplugs SKELETON into a marketplace clone — the runbook "per skeleton bump" cp
# mechanic as a real, idempotent, validated script. DRY-RUN by default: prints the plan and stages
# nothing. Never pushes (marketplace credentials + the commit/push are the operator's step).
# [impl->REQ-DIST-PLUGIN-SKELETON]
#
# Usage:
#   package-skeleton.sh                 # dry-run against the default $MARKET
#   package-skeleton.sh --apply         # actually copy the skeleton subset into $MARKET
#   MARKET=/path/to/cplugs/plugins/sptc package-skeleton.sh --apply
set -u
HERE=$(CDPATH= cd "$(dirname "$0")" && pwd)
ROOT=$(CDPATH= cd "$HERE/../.." && pwd)
PLUGIN="$ROOT/plugin/sptc"
MARKET="${MARKET:-$HOME/.claude/plugins/marketplaces/cplugs/plugins/sptc}"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

# Validate first — refuse to stage an invalid / leaky skeleton.
echo "== validate skeleton =="
if ! sh "$HERE/validate-skeleton.sh" "$PLUGIN"; then
  echo "REFUSING to package: skeleton failed validation (fix above, then retry)." >&2
  exit 1
fi

# The skeleton SUBSET — exactly what cplugs carries (no binary, no manifest, no runtime state).
SUBSET=".claude-plugin/plugin.json hooks skills bootstrap.sh bootstrap.ps1"

echo
echo "== plan ($([ "$APPLY" -eq 1 ] && echo APPLY || echo DRY-RUN)) =="
echo "source : $PLUGIN"
echo "target : $MARKET"
for item in $SUBSET; do
  if [ -e "$PLUGIN/$item" ]; then echo "  stage  $item"; else echo "  WARN   missing source: $item"; fi
done

if [ "$APPLY" -ne 1 ]; then
  echo
  echo "DRY-RUN: nothing copied. Re-run with --apply to stage into \$MARKET, then commit+push the"
  echo "cplugs repo and 'claude plugin install sptc@cplugs' (see docs/RELEASE-RUNBOOK.md)."
  exit 0
fi

mkdir -p "$MARKET/.claude-plugin" "$MARKET/hooks" "$MARKET/skills" || { echo "FATAL: cannot create $MARKET"; exit 2; }
cp "$PLUGIN/.claude-plugin/plugin.json" "$MARKET/.claude-plugin/"
# Replace dir contents wholesale so removed skeleton files don't linger in the marketplace clone.
rm -rf "$MARKET/hooks" "$MARKET/skills"
cp -r "$PLUGIN/hooks" "$MARKET/hooks"
cp -r "$PLUGIN/skills" "$MARKET/skills"
for b in bootstrap.sh bootstrap.ps1; do [ -f "$PLUGIN/$b" ] && cp "$PLUGIN/$b" "$MARKET/"; done

echo
echo "STAGED into $MARKET. Next (operator): cd into the cplugs repo, 'git add plugins/sptc/',"
echo "commit + push, then 'claude plugin install sptc@cplugs' + /reload-plugins."
exit 0
