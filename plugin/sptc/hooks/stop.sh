#!/bin/sh
# Stop: Claude finished responding -> mark the perch idle (also arms the echo-gate fallback,
# L137, since the Stop hook can't inject). [impl->REQ-DIST-HOOKS-API]
. "$CLAUDE_PLUGIN_ROOT/hooks/_common.sh"

input=$(cat)
sid=$(json_str "$input" session_id)
id=$(sptc_self_id "$sid")
[ -z "$id" ] && exit 0

SPT=$(spt_bin)
"$SPT" api --adapter "$ADAPTER" state idle "$id" --session-id "$sid" >/dev/null 2>&1 || true
exit 0
