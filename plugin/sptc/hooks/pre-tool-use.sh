#!/bin/sh
# PreToolUse: MID-TURN message delivery (F-021 reachability parity). A live agent marked BUSY at
# turn-start (UserPromptSubmit) has its inbound messages DEFERRED by spt-core rather than
# idle-PTY-injected; this hook fires before each tool call and DRAINS those deferred messages with
# `api poll <id> --include-deferred` (the checklist pull path — harness-contract/integration-checklist),
# surfacing them as additionalContext so the agent sees a message WHILE working. It is the mid-turn
# complement of the UserPromptSubmit drain (between-turns) — together they cover the legacy spt
# poll+inject-on-PreToolUse reachability. No skill-injection here (no prompt on this event) and NO
# state change (the turn stays busy until Stop). [impl->REQ-DIST-PRETOOL-POLL]
. "$CLAUDE_PLUGIN_ROOT/hooks/_common.sh"

input=$(cat)
sid=$(json_str "$input" session_id)

# Needs a perch. No perch (session not readied) -> nothing to deliver.
id=$(sptc_self_id "$sid")
[ -z "$id" ] && exit 0

SPT=$(spt_bin)
# Mark BUSY here too (idempotent). UserPromptSubmit covers USER turns, but a turn can also start with
# NO user prompt — a Monitor-delivered message (the live-agent relay pipe) triggers a new turn without
# firing UserPromptSubmit, so the perch would still read idle from the prior Stop and a mid-turn
# inbound would idle-PTY-inject (clobber) instead of deferring. PreToolUse fires before every tool
# call, so the FIRST tool call of ANY turn (user, Monitor-triggered, auto-continue) marks busy — the
# earliest reliable turn-active signal when UPS didn't fire. Set BEFORE the drain so inbound landing
# mid-drain also defers. (Residual: a non-user text-only turn marks neither — low risk, no tool/PTY
# interleave; Stop re-idles after.) [impl->REQ-DIST-PRETOOL-POLL]
"$SPT" api --adapter "$ADAPTER" state busy "$id" --session-id "$sid" >/dev/null 2>&1 || true
# --include-deferred: pull messages queued while the perch was busy (the whole point — between-turns
# the UPS drain catches delivered msgs; mid-turn the busy turn defers them, so we must include them).
frames=$("$SPT" api --adapter "$ADAPTER" poll "$id" --session-id "$sid" --include-deferred 2>/dev/null)
[ -z "$frames" ] && exit 0

# Same canonical <EVENT> rendering + spill cap as the UPS drain (sender preserved for reply-correlation).
rendered=$(render_frames "$frames")
spill="${HOME:-${USERPROFILE:-.}}/.claude/sptc-drain-${sid:-unknown}.txt"
sptc_cap_output "$rendered" "$SPTC_CTX_CAP" "$spill"
exit 0
