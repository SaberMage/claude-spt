#!/bin/sh
# Pack the `adapter.spt` release asset — the end-user distribution acquired by
# `spt adapter add --release SaberMage/spt-claude-code` (doyle's --release source, spt v0.7.3+).
# The archive ROOT must hold `manifest.toml` (named EXACTLY that) + `strings/` + the tool binaries;
# spt-core fetches it from the repo's GitHub release, extracts to the durable home, registers the
# root. DRY-RUN by default. Never uploads — the release/tag/upload is the operator's step.
# [impl->REQ-DIST-ADAPTER-RELEASE]
#
# Usage:
#   package-adapter.sh            # dry-run: validate + print the archive plan, write nothing
#   package-adapter.sh --apply    # write dist/adapter.spt (validated)
set -u
HERE=$(CDPATH= cd "$(dirname "$0")" && pwd)
ROOT=$(CDPATH= cd "$HERE/../.." && pwd)
ADAPTER="$ROOT/adapter"
MANIFEST="$ADAPTER/claude-spt.toml"   # renamed to manifest.toml INSIDE the archive (root-only rule)
STRINGS="$ADAPTER/strings"
OUT="${ADAPTER_SPT_OUT:-$ROOT/dist/adapter.spt}"   # overridable so the unit test writes to a tmp file
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

# Native executable suffix (.exe on Windows/MSYS, bare elsewhere) — the archive carries the platform
# binary under its native name so a bare-name command template (`claude-spt-digest …`) resolves it.
EXE=""
[ -f "$ROOT/tools/claude-spt-digest/target/release/claude-spt-digest.exe" ] && EXE=".exe"
DIGEST="$ROOT/tools/claude-spt-digest/target/release/claude-spt-digest$EXE"
PSYCHE="$ROOT/tools/claude-spt-psyche/target/release/claude-spt-psyche$EXE"

# Validate the manifest first — refuse to ship an invalid adapter.
echo "== validate manifest =="
if ! sh "$ROOT/ci/manifest/check-manifest.sh"; then
  echo "REFUSING to package: manifest failed schema validation (fix above, then retry)." >&2
  exit 1
fi

# Require the release binaries (NOT auto-copied by register — they must ride the archive; doyle).
echo
echo "== tool binaries =="
missing=0
for b in "$DIGEST" "$PSYCHE"; do
  if [ -f "$b" ]; then echo "  ok    $b"; else echo "  MISS  $b"; missing=1; fi
done
if [ "$missing" -ne 0 ]; then
  echo "REFUSING to package: build the release binaries first — sh ci/digest/build.sh && sh ci/psyche/build.sh" >&2
  exit 1
fi

echo
echo "== plan ($([ "$APPLY" -eq 1 ] && echo APPLY || echo DRY-RUN)) =="
echo "manifest : $MANIFEST  ->  (archive root) manifest.toml"
echo "strings  : $STRINGS/  ->  (archive root) strings/"
echo "binaries : claude-spt-digest$EXE, claude-spt-psyche$EXE  ->  (archive root)"
echo "asset    : $OUT"
echo "NOTE: the archive is PLATFORM-SPECIFIC (native binaries: '$EXE' build). Multi-OS = per-OS"
echo "      assets, a follow-on. Binaries are NOT copied beside the registered manifest (copy-mode);"
echo "      they must resolve on the target via PATH/absolute (the installer places them)."

if [ "$APPLY" -ne 1 ]; then
  echo
  echo "DRY-RUN: nothing written. Re-run with --apply to write $OUT, then attach it to a GitHub"
  echo "release on the monorepo and 'spt adapter add --release SaberMage/spt-claude-code' (see"
  echo "docs/RELEASE-RUNBOOK.md). Acquisition needs spt v0.7.3+ (counter 15)."
  exit 0
fi

# Stage the archive ROOT in a temp dir, then tar from it so paths are root-relative (no leading dirs).
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/sptc-adapter.XXXXXX") || { echo "FATAL: mktemp failed"; exit 2; }
trap 'rm -rf "$STAGE"' EXIT
cp "$MANIFEST" "$STAGE/manifest.toml"
cp -r "$STRINGS" "$STAGE/strings"
cp "$DIGEST" "$STAGE/claude-spt-digest$EXE"
cp "$PSYCHE" "$STAGE/claude-spt-psyche$EXE"

mkdir -p "$(dirname "$OUT")" || { echo "FATAL: cannot create $(dirname "$OUT")"; exit 2; }
( cd "$STAGE" && tar -czf "$OUT" manifest.toml strings claude-spt-digest$EXE claude-spt-psyche$EXE ) \
  || { echo "FATAL: tar failed"; exit 2; }

# Self-validate the produced archive: manifest.toml must be at the ROOT (no leading path component).
echo
echo "== validate archive =="
if tar -tzf "$OUT" | grep -qx "manifest.toml"; then
  echo "ok   manifest.toml at archive root"
else
  echo "FATAL: manifest.toml is not at the archive root — adapter add --release would reject it" >&2
  exit 1
fi

echo
echo "WROTE $OUT. Next (operator): attach to a GitHub release on SaberMage/spt-claude-code, then"
echo "'spt adapter add --release SaberMage/spt-claude-code' (needs spt v0.7.3+). /reload as needed."
exit 0
