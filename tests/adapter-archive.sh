#!/bin/sh
# Unit test for the adapter.spt packer (ci/publish/package-adapter.sh).
# Asserts the archive-ROOT invariant that `spt adapter add --release` depends on: the packed .spt
# holds manifest.toml (named exactly) + strings/ + both tool binaries at the archive root.
# [unit->REQ-DIST-ADAPTER-RELEASE]
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
PACKER="$ROOT/ci/publish/package-adapter.sh"
rc=0
fail() { printf 'FAIL: %s\n' "$1"; rc=1; }

EXE=""
[ -f "$ROOT/tools/claude-spt-digest/target/release/claude-spt-digest.exe" ] && EXE=".exe"
DIGEST="$ROOT/tools/claude-spt-digest/target/release/claude-spt-digest$EXE"
PSYCHE="$ROOT/tools/claude-spt-psyche/target/release/claude-spt-psyche$EXE"

if [ ! -f "$DIGEST" ] || [ ! -f "$PSYCHE" ]; then
  # No release binaries on this host yet → assert the packer's REFUSE guard fires (no silent pass),
  # and announce the skip of the build-the-archive assertion (no hidden coverage gap).
  if sh "$PACKER" >/dev/null 2>&1; then
    fail "packer should refuse (exit!=0) when release binaries are absent"
  else
    echo "ok   packer refuses when binaries absent (guard works)"
  fi
  echo "SKIP: archive-build assertion — release binaries not present (run ci/{digest,psyche}/build.sh)"
  exit "$rc"
fi

# Binaries present → build a real archive to a temp file and assert its structure.
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
# manifest.toml MUST be at the root (exact, no leading path) — the add --release contract.
echo "$LIST" | grep -qx "manifest.toml" \
  && echo "ok   manifest.toml at archive root" \
  || fail "manifest.toml not at archive root (add --release would reject)"
# strings/ present (any entry under strings/).
echo "$LIST" | grep -q "^strings/" \
  && echo "ok   strings/ present" \
  || fail "strings/ missing from archive"
# both tool binaries present at root.
echo "$LIST" | grep -qx "claude-spt-digest$EXE" \
  && echo "ok   claude-spt-digest$EXE at root" \
  || fail "claude-spt-digest$EXE missing from archive"
echo "$LIST" | grep -qx "claude-spt-psyche$EXE" \
  && echo "ok   claude-spt-psyche$EXE at root" \
  || fail "claude-spt-psyche$EXE missing from archive"
# negative: no stray leading-dir wrapper (e.g. "adapter/manifest.toml").
if echo "$LIST" | grep -q "/manifest.toml"; then
  fail "manifest.toml appears under a subdir — archive root is wrong"
else
  echo "ok   no nested manifest.toml"
fi

# Per-OS asset NAMING (REQ-DIST-ADAPTER-PEROS): the default asset is adapter-<os>-<arch>.spt and the
# name follows SPTC_OS/SPTC_ARCH overrides; the dry-run plan advertises the matching end-user
# `--asset`. (Dry-run = no write; the cross-OS WARN to stderr on a mismatched host is non-fatal.)
# [unit->REQ-DIST-ADAPTER-PEROS]
plan=$(SPTC_OS=linux SPTC_ARCH=aarch64 sh "$PACKER" 2>&1)
echo "$plan" | grep -q "adapter-linux-aarch64\.spt" \
  && echo "ok   per-OS asset name honors SPTC_OS/SPTC_ARCH (adapter-linux-aarch64.spt)" \
  || fail "per-OS override name wrong; plan=[$plan]"
echo "$plan" | grep -q -- "--asset adapter-linux-aarch64\.spt" \
  && echo "ok   dry-run advertises the end-user --asset for that OS" \
  || fail "dry-run missing '--asset adapter-linux-aarch64.spt'; plan=[$plan]"
hostplan=$(sh "$PACKER" 2>&1)
echo "$hostplan" | grep -qE "adapter-(windows|linux|macos|unknown)-[A-Za-z0-9_]+\.spt" \
  && echo "ok   host default asset name matches adapter-<os>-<arch>.spt" \
  || fail "host default asset name not adapter-<os>-<arch>.spt; plan=[$hostplan]"

[ "$rc" -eq 0 ] && echo "PASS: adapter-archive"
exit "$rc"
