#!/bin/sh
# SubagentStop (fires in the PARENT's context): tear down the worker perch. [impl->REQ-DIST-HOOKS-API]
. "$CLAUDE_PLUGIN_ROOT/hooks/_common.sh"

input=$(cat)
sid=$(json_str "$input" session_id)
agent_id=$(json_str "$input" agent_id)
[ -z "$agent_id" ] && exit 0

SPT=$(spt_bin)
"$SPT" api --adapter "$ADAPTER" worker-stop "$agent_id" --session-id "$sid" >/dev/null 2>&1 || true
exit 0
