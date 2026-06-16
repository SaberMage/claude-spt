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
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

# Native executable suffix (.exe on Windows/MSYS, bare elsewhere) — the archive carries the platform
# binary under its native name so a bare-name command template (`claude-spt-digest …`) resolves it.
EXE=""
[ -f "$ROOT/tools/claude-spt-digest/target/release/claude-spt-digest.exe" ] && EXE=".exe"
DIGEST="$ROOT/tools/claude-spt-digest/target/release/claude-spt-digest$EXE"
PSYCHE="$ROOT/tools/claude-spt-psyche/target/release/claude-spt-psyche$EXE"

# PER-OS asset name: the .spt carries native binaries, so it is platform-specific and ships as
# `adapter-<os>-<arch>.spt`. /sptc:setup acquires the matching one via spt's caller-named `--asset`.
# Host-derived from uname; override SPTC_OS/SPTC_ARCH for a cross build / CI. [impl->REQ-DIST-ADAPTER-PEROS]
SPTC_OS="${SPTC_OS:-}"; SPTC_ARCH="${SPTC_ARCH:-}"
if [ -z "$SPTC_OS" ]; then case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*|Windows*) SPTC_OS=windows ;;
  Linux) SPTC_OS=linux ;;
  Darwin) SPTC_OS=macos ;;
  *) SPTC_OS=unknown ;;
esac; fi
if [ -z "$SPTC_ARCH" ]; then case "$(uname -m 2>/dev/null)" in
  x86_64|amd64) SPTC_ARCH=x86_64 ;;
  arm64|aarch64) SPTC_ARCH=aarch64 ;;
  *) SPTC_ARCH="$(uname -m 2>/dev/null || echo unknown)" ;;
esac; fi
# Sanity: the native binary suffix must match the declared OS (windows<->.exe).
case "$SPTC_OS:$EXE" in
  windows:.exe|linux:|macos:) : ;;
  windows:) echo "WARN: SPTC_OS=windows but no .exe binary present — building a non-windows asset?" >&2 ;;
  *:.exe)   echo "WARN: SPTC_OS=$SPTC_OS but a .exe binary is present — cross-OS mismatch?" >&2 ;;
esac
ASSET="adapter-${SPTC_OS}-${SPTC_ARCH}.spt"
OUT="${ADAPTER_SPT_OUT:-$ROOT/dist/$ASSET}"   # overridable so the unit test writes to a tmp file

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
echo "os/arch  : $SPTC_OS/$SPTC_ARCH"
echo "asset    : $OUT  (-> $ASSET)"
echo "NOTE: the archive is PLATFORM-SPECIFIC (native binaries: '$EXE' build) — hence the per-OS name."
echo "      Ship one asset per OS on the same release; /sptc:setup picks the host's via --asset. Build"
echo "      each OS's binaries ON that OS (Windows can't cross-link Linux: 'cc not found'). Binaries"
echo "      are NOT copied beside the registered manifest (copy-mode) — they resolve via PATH/absolute"
echo "      until v0.8.0 Feature B resolves them from the install dir (F-006)."

if [ "$APPLY" -ne 1 ]; then
  echo
  echo "DRY-RUN: nothing written. Re-run with --apply to write $OUT, then attach it to a GitHub"
  echo "release on the monorepo. End users acquire it with 'spt adapter add --release"
  echo "SaberMage/spt-claude-code --asset $ASSET' (see docs/RELEASE-RUNBOOK.md). Needs spt v0.7.3+."
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
echo "WROTE $OUT. Next (operator): attach to a GitHub release on SaberMage/spt-claude-code (alongside"
echo "the other per-OS assets), then end users 'spt adapter add --release SaberMage/spt-claude-code"
echo "--asset $ASSET' (needs spt v0.7.3+). /reload as needed."
exit 0
