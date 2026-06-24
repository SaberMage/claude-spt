#!/bin/sh
# PostToolUse (Write matcher): the CHECKPOINT detector (Feature 2). On a Write to THIS spt-hosted live
# agent's own .claude/<id>-commune.md whose content carries the literal !!checkpoint!! trigger, mark
# the perch idle and self-send a reserved {"checkpoint":"v1",...} signal that loops back through the
# endpoint's own [message-idle-translation-binary], firing the clear+wake macro (the agent-driven
# context reset — the operator's manual /clear, done by the agent itself). spt-hosted live sessions
# ONLY (the loopback needs the broker-held PTY + the spawned translation binary). The !!checkpoint!!
# file-content marker is the WRITE-side trigger; spt-core v0.15.0 strips it from the durable + pending
# context on ingest so it is one-shot. The --json-payload self-send is the DELIVERY-side trigger.
# [impl->REQ-DIST-CHECKPOINT-COMMUNE]
. "$CLAUDE_PLUGIN_ROOT/hooks/_common.sh"

input=$(cat)

# spt-hosted only: the endpoint id rides $SPT_ENDPOINT_ID (injected by [env.SPT_ENDPOINT_ID] on the
# broker-PTY bringup). A harness-hosted session has no translation binary, so checkpoint is inert there.
id="${SPT_ENDPOINT_ID:-}"
[ -z "$id" ] && exit 0

# Only a Write to this agent's own commune file.
sptc_is_commune_write "$(json_str "$input" tool_name)" "$(json_str "$input" file_path)" "$id" || exit 0

# Trigger present in the written content? (Scanned from the hook payload, not a file re-read.)
sptc_has_checkpoint "$input" || exit 0

sid=$(json_str "$input" session_id)
SPT=$(spt_bin)

# Mark idle so the loopback delivery lands on an idle input box, not mid-turn.
"$SPT" api --adapter "$ADAPTER" state idle "$id" --session-id "$sid" >/dev/null 2>&1 || true

# Build the structured checkpoint payload. A custom wake (text between a !!checkpoint!! pair) rides as
# "wake"; otherwise omit it and let the translation binary apply its default ("Proceed with next
# steps") — the default lives in ONE place (the binary). JSON-escape the wake value.
wake=$(sptc_checkpoint_wake "$input")
if [ -n "$wake" ]; then
  payload=$(printf '{"checkpoint":"v1","wake":"%s"}' "$(printf '%s' "$wake" | sptc_json_escape)")
else
  payload='{"checkpoint":"v1"}'
fi

# Self-send the signal back through our own endpoint's translation binary (the proven loopback). The
# body is a harmless human-readable note; the structured trigger lives in the json attr (collision-
# proof). QUEUED and SENT are both success. --json-payload needs spt-core v0.15.0; on an older node the
# send fails and is swallowed (the commune is still saved — checkpoint just won't auto-fire).
printf '%s' "checkpoint requested" | "$SPT" send --from "$id" "$id" --json-payload "$payload" >/dev/null 2>&1 || true
exit 0
