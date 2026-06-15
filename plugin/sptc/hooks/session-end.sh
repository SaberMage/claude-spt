#!/bin/sh
# SessionEnd: soft teardown of the perch (spool/history preserved). Graceful signoff uses
# `api shutdown` instead (driven by the /sptc:signoff skill, not this hook). [impl->REQ-DIST-HOOKS-API]
. "$CLAUDE_PLUGIN_ROOT/hooks/_common.sh"

input=$(cat)
sid=$(json_str "$input" session_id)
id=$(sptc_self_id "$sid")
[ -z "$id" ] && exit 0

SPT=$(spt_bin)
"$SPT" api --adapter "$ADAPTER" session-end "$id" --session-id "$sid" >/dev/null 2>&1 || true
exit 0
