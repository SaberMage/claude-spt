#!/bin/sh
# Generate docs-site/llms.txt — a slim, curated agent index (DOCS-STRATEGY #4) derived
# DETERMINISTICALLY from SUMMARY.md (page order) + each page's first H1. No timestamps, no
# randomness: same sources => byte-identical output, so it can be drift-gated. [impl->REQ-DOCS-DRIFT]
#
# Usage: gen-llms.sh [--check]
#   (default) write docs-site/llms.txt
#   --check   print to stdout only (the drift gate diffs this against the committed file)
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
SITE="$ROOT/docs-site"
SRC="$SITE/src"
SUMMARY="$SRC/SUMMARY.md"
OUT="$SITE/llms.txt"
[ -f "$SUMMARY" ] || { echo "FATAL: no $SUMMARY" >&2; exit 2; }

# First H1 ("# ...") of a page, trimmed. Falls back to the file stem.
page_title() {
  _t=$(sed -n 's/^#[[:space:]]\{1,\}\(.*\)$/\1/p' "$1" 2>/dev/null | head -n1)
  [ -n "$_t" ] && printf '%s' "$_t" || basename "$1" .md
}

emit() {
  printf '# claude-spt\n\n'
  printf '> Spacetime (spt) adapter for Claude Code: agent messaging, live agents, and an invisible spt-core installer, delivered as a Claude Code plugin. Built against spt-core'\''s published public surface only.\n\n'
  printf '## Docs\n\n'
  # Walk SUMMARY.md in order; for each `[label](./path.md)` link, emit a real title + relative link.
  # site-relative .html link (stable URLs; DOCS-STRATEGY #9). Markdown links only, in file order.
  grep -o '(\./[A-Za-z0-9_./-]*\.md)' "$SUMMARY" | sed 's/^(\.\///; s/)$//' | while IFS= read -r rel; do
    [ -f "$SRC/$rel" ] || continue
    _title=$(page_title "$SRC/$rel")
    _html=$(printf '%s' "$rel" | sed 's/\.md$/.html/')
    printf -- '- [%s](%s)\n' "$_title" "$_html"
  done
}

if [ "${1:-}" = "--check" ]; then
  emit
else
  emit > "$OUT"
  echo "wrote $OUT"
fi
