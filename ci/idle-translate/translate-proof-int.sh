#!/bin/sh
# Integration proof: `spt adapter translate-proof` spawns + feeds the claude-spt
# [message-idle-translation-binary] (cc-spt-idle-translate) EXACTLY as the daemon does at idle
# delivery (init line then the --event envelope), reads back the emitted keystroke-command stream,
# and gates it. This is the EMIT half of REQ-DIST-IDLE-TRANSLATE — the cross-process author-time proof
# (ADR-0022, the EMIT-half mirror of digest-proof). It does NOT exercise the daemon's atomic PTY APPLY
# or controller buffering — that half stays the real-claude bringup int (deferred). [int->REQ-DIST-IDLE-TRANSLATE]
#
# Uses the v0.13.2 `--dir`/`--manifest` override (F-011 closed, W5) to proof the DEV binary straight
# from its build dir against the bare-file manifest: --dir resolves the binary (before PATH) exactly
# as the daemon does, --manifest pins the bare-file manifest. NO registry mutation — the prior form
# staged a disposable install dir and `adapter add`/`adapter remove claude-spt`, which soft-removed
# the REAL registered claude-spt on cleanup. Read-only now, so NO SPTC_ACCEPTANCE gate. Needs
# spt >= 0.13.2 (the --dir/--manifest options) + a built binary. Idempotent.
# Run: sh ci/idle-translate/translate-proof-int.sh   (exit 0 = pass).
#
# GREEN against the {commit}-terminated binary: emits the 4-command choreography ctrl+s · 50ms ·
# {text:"<envelope>\r"} · {commit:true}, exit 0 / TRANSLATE_PROOF_OK / "commit: yes". The no-{commit}
# form FAULTs (the F-016 defect the proof's no-commit gate catches).
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
MANIFEST="$ROOT/adapter/claude-spt.toml"
RELDIR="$ROOT/tools/cc-spt-idle-translate/target/release"
EVENT='<EVENT type="msg" from="ci">translate-proof int probe</EVENT>'

command -v spt >/dev/null 2>&1 || { echo "SKIP: no spt on PATH"; exit 0; }

# --dir/--manifest landed in spt v0.13.2 — capability-detect rather than version-parse.
if ! spt adapter translate-proof --help 2>&1 | grep -q -- '--dir'; then
  echo "SKIP: spt 'adapter translate-proof' has no --dir/--manifest (needs v0.13.2). Binary itself: cargo tests green."
  exit 0
fi

BIN="$RELDIR/cc-spt-idle-translate"
[ -x "$BIN" ] || BIN="$RELDIR/cc-spt-idle-translate.exe"
[ -x "$BIN" ] || { echo "SKIP: binary not built (run sh ci/idle-translate/build.sh)"; exit 0; }

# Proof the dev binary in-place: --dir resolves the binary (before PATH) like the daemon, --manifest
# pins the bare-file gh_release manifest — no extracted install, no registry touch.
out=$(spt adapter translate-proof claude-spt --event "$EVENT" --manifest "$MANIFEST" --dir "$RELDIR" 2>&1)
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
