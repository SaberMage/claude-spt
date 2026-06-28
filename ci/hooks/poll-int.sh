#!/bin/sh
# Integration proof for the UserPromptSubmit message-drain path against a REAL spt-core (>= v0.7.1):
# the published `api poll` surface emits the canonical self-delimiting <EVENT> envelope,
# and our hook parser (render_frames) decodes it correctly. This is the confirm-match that closes
# REQ-MSG-ENVELOPE end-to-end: design -> impl -> ship -> real-surface-verify. F-002 (no inter-frame
# delimiter) is dissolved — multi-message drains split cleanly on </EVENT>, no __REPLY_TO__ relic.
# [int->REQ-DIST-HOOKS-API] [int->REQ-UPS-INJECTION]
#
# v0.7.1 is the floor: the <EVENT> poll surface ships in 0.7.1; 0.7.0 still emits the __REPLY_TO__
# relic, so this SKIPs there. Mutates node-local perch/spool state (a throwaway perch, torn down on
# exit), so it is gated behind SPTC_ACCEPTANCE=1. Idempotent.
# Run: SPTC_ACCEPTANCE=1 sh ci/hooks/poll-int.sh   (exit 0 = pass).
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
ADAPTER=claude-spt
# Disposable perch id — NEVER a live agent's id (REQ-HAZARD-PERCH-COLLISION: a colliding id tears
# down the live agent's perch + poll stream, name-keyed last-establish-wins).
BID=sptc-poll-int
BSID=sptc-poll-int-sess

if [ "${SPTC_ACCEPTANCE:-0}" != "1" ]; then echo "SKIP: set SPTC_ACCEPTANCE=1 to run (mutates perch/spool state)"; exit 0; fi
command -v spt >/dev/null 2>&1 || { echo "SKIP: no spt on PATH"; exit 0; }
ver=$(spt --version 2>/dev/null | awk '{print $NF}')
case "$ver" in
  0.7.0|0.6.*|0.5.*|0.4.*|0.3.*|0.2.*|0.1.*|0.0.*) echo "SKIP: spt $ver < 0.7.1 (<EVENT> poll surface ships in 0.7.1; older emits the __REPLY_TO__ relic)"; exit 0 ;;
esac

fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
# Tear down the throwaway perch however we exit.
trap 'spt endpoint shutdown "$BID" >/dev/null 2>&1 || true; spt endpoint stop "$BID" >/dev/null 2>&1 || true' EXIT INT TERM

# Establish a pollable perch (non-blocking: seed + bind, no listener -> sends spool).
spt api --adapter "$ADAPTER" seed --pid $$ --session-id "$BSID" >/dev/null 2>&1
bound=$(spt api --adapter "$ADAPTER" bind "$BID" --set-session-id "$BSID" --session-id "$BSID" 2>&1)
case "$bound" in *BOUND:"$BID"*) ok "perch bound (non-blocking)" ;; *) bad "bind failed: $bound"; echo "MSG-ENVELOPE-INT FAIL"; exit 1 ;; esac

# Drain & discard any resurfaced notifications so the assertion sees only our test message.
spt api --adapter "$ADAPTER" poll "$BID" --session-id "$BSID" >/dev/null 2>&1

# Send one message with body specials (newline + < > & ") from a known sender, then drain raw.
printf 'hello from probe<NL>second <line> & "stuff"' | sed 's/<NL>/\
/' | spt send "$BID" --from probe-int >/dev/null 2>&1
raw=$(spt api --adapter "$ADAPTER" poll "$BID" --session-id "$BSID" 2>&1)

# 1. Canonical <EVENT type="msg" from=…> envelope with correct body escaping; no relic.
expected='<EVENT type="msg" from="probe-int">hello from probe<br>second &lt;line&gt; &amp; &quot;stuff&quot;</EVENT>'
case "$raw" in *"$expected"*) ok "api poll emits canonical <EVENT> msg envelope (escaped body)" ;; *) bad "envelope mismatch; raw=[$raw]" ;; esac
case "$raw" in *__REPLY_TO__*) bad "raw drain still carries the __REPLY_TO__ relic" ;; *) ok "no __REPLY_TO__ relic (canonical poll envelope shipped)" ;; esac

# 2. Hook BINARY confirm-match (D1): the real `claude-spt hook UserPromptSubmit` drains the live perch
#    and renders the canonical <EVENT> drain to our <sptc_messages> additionalContext shape — the same
#    parser, now in the binary (was render_frames in _common.sh). Send a fresh message with body
#    specials, run the hook (it resolves the perch via whoami off OWL_SESSION_ID, marks busy, polls
#    --include-deferred, renders), then re-idle + drain residue so step 3's plain poll stays clean.
#    [int->REQ-DIST-HOOK-BINARY] [int->REQ-UPS-INJECTION]
HOOKBIN="$ROOT/tools/claude-spt/target/release/claude-spt.exe"
[ -x "$HOOKBIN" ] || HOOKBIN="$ROOT/tools/claude-spt/target/release/claude-spt"
if [ -x "$HOOKBIN" ]; then
  printf 'hello from probe<NL>second <line> & "stuff"' | sed 's/<NL>/\
/' | spt send "$BID" --from probe-int >/dev/null 2>&1
  # The binary resolves the perch via `spt whoami` with OWL_SESSION_ID set from the stdin session_id.
  rendered=$(printf '%s' "{\"session_id\":\"$BSID\",\"prompt\":\"\"}" | "$HOOKBIN" hook UserPromptSubmit --host-pid $$ 2>/dev/null)
  want=$(printf '<sptc_messages from="probe-int">\nhello from probe\nsecond <line> & "stuff"\n</sptc_messages>')
  case "$rendered" in *"$want"*) ok "binary hook confirm-match: live drain -> <sptc_messages>" ;; *) bad "binary render mismatch; got=[$rendered]" ;; esac
  # Re-idle the perch (the hook marked it busy) and drain any residue so step 3 is unaffected.
  spt api --adapter "$ADAPTER" state idle "$BID" --session-id "$BSID" >/dev/null 2>&1
  spt api --adapter "$ADAPTER" poll "$BID" --session-id "$BSID" --include-deferred >/dev/null 2>&1
else
  echo "SKIP: claude-spt binary not built (cargo build --release) — binary hook confirm-match needs it"
fi

# 3. Multi-message: two sends drain as two whole envelopes (self-delimiting; F-002 dissolved).
printf 'one' | spt send "$BID" --from alice >/dev/null 2>&1
printf 'two' | spt send "$BID" --from bob >/dev/null 2>&1
multi=$(spt api --adapter "$ADAPTER" poll "$BID" --session-id "$BSID" 2>&1)
n=$(printf '%s\n' "$multi" | grep -c 'type="msg"')
[ "$n" -eq 2 ] && ok "multi-message: 2 whole <EVENT> envelopes split on </EVENT>" || bad "expected 2 msg envelopes, got $n"

[ "$fail" -eq 0 ] && { echo "MSG-ENVELOPE-INT OK"; exit 0; } || { echo "MSG-ENVELOPE-INT FAIL"; exit 1; }
