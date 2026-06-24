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
# GREEN against the {commit}-terminated binary: emits the 6-command choreography ctrl+s · 50ms ·
# {text:"<envelope>"} · 50ms · {key:enter} · {commit:true}, exit 0 / TRANSLATE_PROOF_OK / "commit: yes".
# The submit is a discrete {key:enter} AFTER the text (a trailing \r byte does NOT submit a CC message,
# corrected 2026-06-23). The no-{commit} form FAULTs (the F-016 defect the proof's no-commit gate catches).
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
# The submit is a discrete enter keypress (NOT a trailing \r in the text — a \r byte does not submit CC).
case "$out" in
  *enter*) echo "ok  emitted the discrete {key:enter} submit" ;;
  *) echo "FAIL: no {key:enter} submit in the command stream:"; printf '%s\n' "$out"; rc=1 ;;
esac
# ...and the text command must NOT carry a trailing \r anymore.
case "$out" in
  *'\r"'*) echo "FAIL: text still carries a trailing \\r (should be a discrete enter):"; printf '%s\n' "$out"; rc=1 ;;
  *) echo "ok  text command carries no trailing \\r" ;;
esac
# The envelope is FRAMED across multiple lines for visual distinction: a raw \n after the opening
# tag and before the closing </EVENT>. CC soft-newlines a bare \n (empirically gated 2026-06-24), so
# this renders as one user turn spanning lines, not an early submit. The emitted {text} carries the
# two deliberate framing newlines (JSON-escaped as \n in the command stream). [int->REQ-DIST-IDLE-MULTILINE]
case "$out" in
  *'>\n'*'\n</EVENT>'*) echo "ok  envelope framed across lines (\\n after opening tag and before </EVENT>)" ;;
  *) echo "FAIL: text is not framed across lines (multi-line envelope missing):"; printf '%s\n' "$out"; rc=1 ;;
esac

# ── CHECKPOINT branch (Feature 2) ────────────────────────────────────────────────────────────────
# An envelope carrying a `json="{"checkpoint":"v1",…}"` attr (what `spt send --json-payload` composes,
# v0.15.0) fires the clear+wake macro INSTEAD of normal delivery. This is the EMIT half of the binary's
# checkpoint branch — proven here by feeding translate-proof an envelope with the json attr directly
# (no --json-payload needed, so it runs on the pre-0.15.0 daemon). The send-side composition + the live
# self-send loopback stay the heavier real-claude int (deferred, like the multi-line APPLY half).
# [int->REQ-DIST-CHECKPOINT-COMMUNE]
CKPT='<EVENT type="msg" from="self" json="{&quot;checkpoint&quot;:&quot;v1&quot;,&quot;wake&quot;:&quot;Resume now&quot;}">checkpoint requested</EVENT>'
ck=$(spt adapter translate-proof claude-spt --event "$CKPT" --manifest "$MANIFEST" --dir "$RELDIR" 2>&1)
case "$ck" in
  *'text  "/clear"'*) echo "ok  checkpoint envelope fires the /clear macro" ;;
  *) echo "FAIL: checkpoint envelope did not emit /clear:"; printf '%s\n' "$ck"; rc=1 ;;
esac
case "$ck" in
  *'text  "Resume now"'*) echo "ok  checkpoint macro types the custom wake directive" ;;
  *) echo "FAIL: checkpoint macro missing the custom wake:"; printf '%s\n' "$ck"; rc=1 ;;
esac
case "$ck" in
  *'delay 500ms'*) echo "ok  checkpoint macro waits for /clear to settle (500ms)" ;;
  *) echo "FAIL: checkpoint macro missing the post-/clear settle:"; printf '%s\n' "$ck"; rc=1 ;;
esac
case "$ck" in
  *'commit: yes'*) echo "ok  checkpoint macro terminates with the mandatory {commit}" ;;
  *) echo "FAIL: checkpoint macro missing the {commit} terminator:"; printf '%s\n' "$ck"; rc=1 ;;
esac
# Default wake when the payload carries no `wake` field.
CKPT_DEF='<EVENT type="msg" from="self" json="{&quot;checkpoint&quot;:&quot;v1&quot;}">checkpoint requested</EVENT>'
ckd=$(spt adapter translate-proof claude-spt --event "$CKPT_DEF" --manifest "$MANIFEST" --dir "$RELDIR" 2>&1)
case "$ckd" in
  *'text  "Proceed with next steps"'*) echo "ok  checkpoint without a wake uses the default" ;;
  *) echo "FAIL: default wake not applied:"; printf '%s\n' "$ckd"; rc=1 ;;
esac
# A normal (non-checkpoint) message must NOT fire the macro.
case "$out" in
  *'/clear'*) echo "FAIL: a normal message emitted /clear (checkpoint false-positive):"; printf '%s\n' "$out"; rc=1 ;;
  *) echo "ok  normal delivery never fires the /clear macro" ;;
esac

[ "$rc" -eq 0 ] && { echo "TRANSLATE-PROOF-INT OK"; exit 0; } || { echo "TRANSLATE-PROOF-INT FAIL"; exit 1; }
