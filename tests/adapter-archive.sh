#!/bin/sh
# Unit test for the adapter.spt packer (ci/publish/package-adapter.sh).
# Asserts the MULTI-PLATFORM fat-archive invariants `spt adapter add --release` depends on (ADR-0024
# W1, spt-core >= 0.13.2): one .spt holds the SHARED manifest.toml (named exactly) + strings/ at the
# archive ROOT, plus each recognized target-triple's binaries under a <triple>/ dir mirroring the
# flat-root tree. spt-core classifies on the top-level triple dir and flattens this node's triple into
# the install dir, so a bare-name command token still resolves. [unit->REQ-DIST-ADAPTER-RELEASE]
# [unit->REQ-DIST-ADAPTER-PEROS]
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
PACKER="$ROOT/ci/publish/package-adapter.sh"
WIN_TRIPLE=x86_64-pc-windows-msvc
LINUX_TRIPLE=x86_64-unknown-linux-gnu
BINS="claude-spt"  # the ONE consolidated tool binary: digest/psyche/post-update/translate subcommands (ADR-0006; translate folded D3)
rc=0
fail() { printf 'FAIL: %s\n' "$1"; rc=1; }

# The fat archive needs BOTH platforms' release binaries. Probe both triples.
have_all=1
for b in $BINS; do
  [ -f "$ROOT/tools/$b/target/release/$b.exe" ] || have_all=0
  [ -f "$ROOT/tools/$b/target/$LINUX_TRIPLE/release/$b" ] || have_all=0
done

if [ "$have_all" -ne 1 ]; then
  # Missing a platform → assert the packer's REFUSE guard fires (no silent pass), then skip the
  # archive-build assertion (no hidden coverage gap). Both platforms are required for a fat archive.
  if sh "$PACKER" --apply >/dev/null 2>&1; then
    fail "packer should refuse (exit!=0) when a platform's binaries are absent"
  else
    echo "ok   packer refuses --apply when a platform's binaries absent (guard works)"
  fi
  echo "SKIP: archive-build assertion — need BOTH platforms (win native + linux cross-build) present"
  exit "$rc"
fi

# Both platforms present → build a real fat archive to a temp file and assert its structure.
TMP=$(mktemp -d "${TMPDIR:-/tmp}/sptc-archtest.XXXXXX") || { echo "FAIL: mktemp"; exit 1; }
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/adapter.spt"

if ADAPTER_SPT_OUT="$OUT" sh "$PACKER" --apply >/dev/null 2>&1; then
  echo "ok   packer --apply succeeded"
else
  fail "packer --apply exited non-zero"
  exit "$rc"
fi
[ -f "$OUT" ] || { fail "no archive written at $OUT"; exit "$rc"; }

LIST=$(tar -tzf "$OUT")
# SHARED manifest.toml MUST be at the root (exact, no leading path) — the add --release contract.
echo "$LIST" | grep -qx "manifest.toml" \
  && echo "ok   shared manifest.toml at archive root" \
  || fail "manifest.toml not at archive root (add --release would reject)"
# SHARED strings/ at root (not under a triple).
echo "$LIST" | grep -q "^strings/" \
  && echo "ok   shared strings/ at root" \
  || fail "strings/ missing from archive root"
# Each triple carries all the tool binaries, under its <triple>/ dir, mirroring the flat-root tree.
for b in $BINS; do
  echo "$LIST" | grep -qx "$WIN_TRIPLE/$b.exe" \
    && echo "ok   $WIN_TRIPLE/$b.exe present" \
    || fail "$WIN_TRIPLE/$b.exe missing from archive"
  echo "$LIST" | grep -qx "$LINUX_TRIPLE/$b" \
    && echo "ok   $LINUX_TRIPLE/$b present" \
    || fail "$LINUX_TRIPLE/$b missing from archive"
done
# Negative: the SHARED files must NOT sit under a triple (would not be shared), and no nested wrapper.
if echo "$LIST" | grep -qE "^$WIN_TRIPLE/(manifest\.toml|strings/)"; then
  fail "manifest/strings duplicated under a triple — they must be shared at root only"
else
  echo "ok   manifest/strings not duplicated under a triple"
fi
# Negative: no UNRECOGNIZED top-level dir (spt-core would silently flatten it as a shared-root entry).
badtop=$(echo "$LIST" | awk -F/ 'NF>1 {print $1}' | sort -u | grep -vE "^(strings|$WIN_TRIPLE|$LINUX_TRIPLE)$" || true)
if [ -n "$badtop" ]; then
  fail "unrecognized top-level dir(s) [$badtop] — spt-core would mis-place them flat (silent footgun)"
else
  echo "ok   no stray/unrecognized top-level dirs (only strings/ + the two recognized triples)"
fi

# A fat archive REQUIRES min_spt_core_version >= 0.13.2 — the packer must refuse a lower floor.
# (Smoke the guard by reading the dry-run plan's advertised floor.)
plan=$(sh "$PACKER" 2>&1)
echo "$plan" | grep -qE "min_spt_core 0\.(1[3-9]|[2-9][0-9])" \
  && echo "ok   packer advertises a fat-capable floor (>= 0.13.2)" \
  || fail "packer floor advertisement missing/too low; plan=[$plan]"

[ "$rc" -eq 0 ] && echo "PASS: adapter-archive"
exit "$rc"
