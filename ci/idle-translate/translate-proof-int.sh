#!/bin/sh
# Integration proof: `spt adapter translate-proof` spawns + feeds the claude-spt
# [message-idle-translation-binary] (cc-spt-idle-translate) EXACTLY as the daemon does at idle
# delivery (init line then the --event envelope), reads back the emitted keystroke-command stream,
# and gates it. This is the EMIT half of REQ-DIST-IDLE-TRANSLATE — the cross-process author-time proof
# (ADR-0022, the EMIT-half mirror of digest-proof). It does NOT exercise the daemon's atomic PTY APPLY
# or controller buffering — that half stays the real-claude bringup int (deferred). [int->REQ-DIST-IDLE-TRANSLATE]
#
# Gated behind SPTC_ACCEPTANCE=1 (mutates the node-local adapter registry: add + soft-remove) + a
# present spt >= 0.13.1 (translate-proof landed in v0.13.1 / counter 28) + a built binary. Idempotent.
# Run: SPTC_ACCEPTANCE=1 sh ci/idle-translate/translate-proof-int.sh
#
# GREEN since spt v0.13.1 (counter 28) against the {commit}-terminated binary: emits the 4-command
# choreography ctrl+s · 50ms · {text:"<envelope>\r"} · {commit:true}, exit 0 / TRANSLATE_PROOF_OK /
# "commit: yes". The no-{commit} form FAULTs (the F-016 defect the proof's no-commit gate catches).
#
# INSTALL-DIR NOTE: claude-spt declares [update] avenue="gh_release", so a bare-file `adapter add`
# registers it GhReleaseManaged and the runtime resolver wants the EXTRACTED install (manifest.toml +
# the binary co-located), not the dev source file. So this int stages a real install DIR — manifest.toml
# (the renamed manifest) + strings/ + the built binary — exactly the shape `adapter add --release`
# extracts, and points the adapter at it. (The sibling ci/digest/digest-proof-int.sh predates this
# GhReleaseManaged behavior and uses the now-stale bare-file form.)
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
MANIFEST="$ROOT/adapter/claude-spt.toml"
STRINGS="$ROOT/adapter/strings"
RELDIR="$ROOT/tools/cc-spt-idle-translate/target/release"
EVENT='<EVENT type="msg" from="ci">translate-proof int probe</EVENT>'

[ "${SPTC_ACCEPTANCE:-0}" = "1" ] || { echo "SKIP: set SPTC_ACCEPTANCE=1 to run (mutates the adapter registry)"; exit 0; }
command -v spt >/dev/null 2>&1 || { echo "SKIP: no spt on PATH"; exit 0; }

# translate-proof is a v0.13.1+ subcommand — announce the version gap rather than fail on an old binary.
if ! spt adapter --help 2>&1 | grep -q 'translate-proof'; then
  echo "SKIP: spt has no 'adapter translate-proof' (needs v0.13.1 / counter 28+). Binary itself: cargo tests green."
  exit 0
fi

BIN="$RELDIR/cc-spt-idle-translate"
[ -x "$BIN" ] || BIN="$RELDIR/cc-spt-idle-translate.exe"
[ -x "$BIN" ] || { echo "SKIP: binary not built (run sh ci/idle-translate/build.sh)"; exit 0; }

# Stage the install dir the resolver expects (manifest.toml + strings/ + the binary co-located).
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/cc-xlate-int.XXXXXX") || { echo "FAIL: mktemp"; exit 1; }
trap 'spt adapter remove claude-spt >/dev/null 2>&1 || true; rm -rf "$STAGE"' EXIT INT TERM
cp "$MANIFEST" "$STAGE/manifest.toml" || { echo "FAIL: stage manifest"; exit 1; }
cp -r "$STRINGS" "$STAGE/strings"     || { echo "FAIL: stage strings"; exit 1; }
cp "$BIN" "$STAGE/"                    || { echo "FAIL: stage binary"; exit 1; }

spt adapter add "$STAGE" >/dev/null 2>&1 || { echo "FAIL: spt adapter add (install dir)"; exit 1; }

out=$(spt adapter translate-proof claude-spt --event "$EVENT" 2>&1)
rc=0
case "$out" in
  *TRANSLATE_PROOF_OK*) echo "ok  translate-proof: TRANSLATE_PROOF_OK" ;;
  *) echo "FAIL: translate-proof did not pass:"; printf '%s\n' "$out"; exit 1 ;;
esac
# The {commit} terminator is the F-016 fix — assert the proof saw it (no-commit would FAULT live).
case "$out" in
  *"commit: yes"*) echo "ok  emitted the mandatory {commit} terminator (commit: yes)" ;;
  *) echo "FAIL: proof reports no commit terminator (the F-016 fault condition):"; printf '%s\n' "$out"; rc=1 ;;
esac
# And the verbatim \r submit rides inside the text command (not a separate enter key).
case "$out" in
  *'\r"'*) echo "ok  text command carries the trailing \\r submit" ;;
  *) echo "FAIL: no trailing \\r in the text command:"; printf '%s\n' "$out"; rc=1 ;;
esac

[ "$rc" -eq 0 ] && { echo "TRANSLATE-PROOF-INT OK"; exit 0; } || { echo "TRANSLATE-PROOF-INT FAIL"; exit 1; }
