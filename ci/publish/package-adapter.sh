#!/bin/sh
# Pack the SINGLE MULTI-PLATFORM `adapter.spt` release asset — the end-user distribution acquired by
# `spt adapter add --release SaberMage/claude-spt` and carried by the `[update] gh_release`
# avenue. ONE fat archive covers every supported platform (ADR-0024 W1, spt-core >= 0.13.2).
# The release/install/update repo is `SaberMage/claude-spt` (renamed from spt-claude-code, U3/ADR-0005).
# [impl->REQ-DIST-ADAPTER-RELEASE] [impl->REQ-DIST-ADAPTER-PEROS] [impl->REQ-DIST-NAME-UNIFY]
#
#   adapter.spt (tar.gz)
#   ├── manifest.toml                 ← SHARED, at archive root (renamed from claude-spt.toml)
#   ├── strings/                      ← SHARED, at archive root
#   ├── x86_64-pc-windows-msvc/       ← this triple's binary, mirroring the flat-root tree
#   │   ├── claude-spt.exe
#   └── x86_64-unknown-linux-gnu/
#       └── claude-spt
#
# spt-core CLASSIFIES on top-level entry names: a known target-triple dir ⇒ multi-platform; it places
# the shared-root entries + FLATTENS this node's <triple>/* into the install dir (so a bare-name
# command token still resolves at <install_dir>/<program>, REQ-INSTALL-11). This RETIRES the F-014
# per-OS stopgap (the old single-OS `adapter.spt`-by-default that broke on a foreign host).
#
# CONSTRAINTS (doyle, extract_release_archive): only x86_64-pc-windows-msvc + x86_64-unknown-linux-gnu
# are recognized triples — an UNRECOGNIZED dir name is silently treated as a shared-root entry and
# lands flat (no error), so for platforms beyond these two ship a separate single-triple asset via
# `--asset` instead of adding a dir here. A fat archive REQUIRES the manifest's
# min_spt_core_version >= 0.13.2 (older spt-core cannot read it). DRY-RUN by default; never uploads.
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
TOOLS="$ROOT/tools"
OUT="${ADAPTER_SPT_OUT:-$ROOT/dist/adapter.spt}"   # overridable so the unit test writes to a tmp file
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

# The recognized triples and where each platform's release binaries live. A native Windows build lands
# in target/release; the Linux build is cross-compiled (cargo-zigbuild) into
# target/x86_64-unknown-linux-gnu/release. Override SPTC_WIN_RELSUB / SPTC_LINUX_RELSUB for a
# non-default layout. There is now ONE tool binary: the consolidated claude-spt crate carries all four
# subcommands — digest / psyche / post-update / translate (the last folded in at the v0.8.0 cut once
# spt-core v0.16.0 gave [message-idle-translation-binary] a `command` field — ADR-0006/D3).
WIN_TRIPLE=x86_64-pc-windows-msvc
LINUX_TRIPLE=x86_64-unknown-linux-gnu
WIN_RELSUB="${SPTC_WIN_RELSUB:-release}"
LINUX_RELSUB="${SPTC_LINUX_RELSUB:-$LINUX_TRIPLE/release}"
BINS="claude-spt"

# Validate the manifest first — refuse to ship an invalid adapter.
echo "== validate manifest =="
if ! sh "$ROOT/ci/manifest/check-manifest.sh"; then
  echo "REFUSING to package: manifest failed schema validation (fix above, then retry)." >&2
  exit 1
fi

# A fat archive is only readable on spt-core >= 0.13.2 — the manifest MUST declare that floor.
floor=$(grep -E '^min_spt_core_version' "$MANIFEST" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
case "$floor" in
  0.13.2|0.13.[3-9]*|0.1[4-9].*|0.[2-9][0-9].*|[1-9].*) : ;;
  *) echo "REFUSING to package: min_spt_core_version is '$floor' but a multi-platform fat .spt needs >= 0.13.2 (doyle)." >&2; exit 1 ;;
esac

# Require BOTH platforms' release binaries (NOT auto-copied by register — they ride the archive).
echo
echo "== tool binaries =="
missing=0
win_path()   { echo "$TOOLS/$1/target/$WIN_RELSUB/$1.exe"; }
linux_path() { echo "$TOOLS/$1/target/$LINUX_RELSUB/$1"; }
for b in $BINS; do
  for p in "$(win_path "$b")" "$(linux_path "$b")"; do
    if [ -f "$p" ]; then echo "  ok    $p"; else echo "  MISS  $p"; missing=1; fi
  done
done
if [ "$missing" -ne 0 ]; then
  echo "REFUSING to package: build BOTH platforms first — Windows: sh ci/digest/build.sh;" >&2
  echo "Linux (cross): cargo-zigbuild --release --target $LINUX_TRIPLE for each tool crate (see docs/RELEASE-RUNBOOK.md)." >&2
  exit 1
fi

echo
echo "== plan ($([ "$APPLY" -eq 1 ] && echo APPLY || echo DRY-RUN)) =="
echo "manifest : $MANIFEST  ->  (root) manifest.toml          [min_spt_core $floor]"
echo "strings  : $STRINGS/  ->  (root) strings/"
echo "win bins : -> $WIN_TRIPLE/{$(echo $BINS | tr ' ' ',')}.exe"
echo "linux bins: -> $LINUX_TRIPLE/{$(echo $BINS | tr ' ' ',')}"
echo "asset    : $OUT  (the single fat adapter.spt — auto-resolves the host triple on install)"

if [ "$APPLY" -ne 1 ]; then
  echo
  echo "DRY-RUN: nothing written. Re-run with --apply to write $OUT, then attach it as 'adapter.spt'"
  echo "to a GitHub release on the monorepo. End users: 'spt adapter add --release SaberMage/claude-spt'"
  echo "(default asset adapter.spt). Needs spt v0.13.2+. See docs/RELEASE-RUNBOOK.md."
  exit 0
fi

# Stage the archive ROOT in a temp dir, then tar from it so paths are root-relative (no leading dirs).
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/sptc-adapter.XXXXXX") || { echo "FATAL: mktemp failed"; exit 2; }
trap 'rm -rf "$STAGE"' EXIT
cp "$MANIFEST" "$STAGE/manifest.toml"
cp -r "$STRINGS" "$STAGE/strings"
mkdir -p "$STAGE/$WIN_TRIPLE" "$STAGE/$LINUX_TRIPLE"
for b in $BINS; do
  cp "$(win_path "$b")"   "$STAGE/$WIN_TRIPLE/$b.exe"
  cp "$(linux_path "$b")" "$STAGE/$LINUX_TRIPLE/$b"
done

mkdir -p "$(dirname "$OUT")" || { echo "FATAL: cannot create $(dirname "$OUT")"; exit 2; }
( cd "$STAGE" && tar -czf "$OUT" manifest.toml strings "$WIN_TRIPLE" "$LINUX_TRIPLE" ) \
  || { echo "FATAL: tar failed"; exit 2; }

# Self-validate the produced archive: shared manifest at ROOT + BOTH triple dirs present.
echo
echo "== validate archive =="
listing=$(tar -tzf "$OUT")
fatal=0
echo "$listing" | grep -qx "manifest.toml" || { echo "FATAL: manifest.toml not at archive root" >&2; fatal=1; }
echo "$listing" | grep -q "^$WIN_TRIPLE/claude-spt.exe$" || { echo "FATAL: missing $WIN_TRIPLE/ binaries" >&2; fatal=1; }
echo "$listing" | grep -q "^$LINUX_TRIPLE/claude-spt$"   || { echo "FATAL: missing $LINUX_TRIPLE/ binaries" >&2; fatal=1; }
# Guard the footgun: no UNRECOGNIZED top-level dir (would silently flatten as a shared-root entry).
badtop=$(echo "$listing" | awk -F/ 'NF>1 {print $1}' | sort -u | grep -vE "^(strings|$WIN_TRIPLE|$LINUX_TRIPLE)$" || true)
[ -n "$badtop" ] && { echo "FATAL: unrecognized top-level dir(s) [$badtop] — spt-core would mis-place them flat" >&2; fatal=1; }
[ "$fatal" -eq 0 ] || exit 1
echo "ok   manifest.toml + strings/ at root; $WIN_TRIPLE/ + $LINUX_TRIPLE/ binaries present; no stray top-level dirs"

echo
echo "WROTE $OUT (single fat adapter.spt). Next (operator): attach as 'adapter.spt' to a GitHub release"
echo "on SaberMage/claude-spt; end users 'spt adapter add --release SaberMage/claude-spt' (spt"
echo "v0.13.2+). The fat archive auto-resolves the host's binaries — no per-OS --asset needed."
exit 0
