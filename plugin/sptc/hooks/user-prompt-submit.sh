#!/bin/sh
# UserPromptSubmit: drain delivered messages (the hook-injection channel, L149) and surface
# them to CC as additionalContext. SINGLE-MESSAGE path only — the multi-frame splitter is HELD
# pending spt-core F-002 (api poll agent path has no inter-frame delimiter). [impl->REQ-UPS-INJECTION]
. "$CLAUDE_PLUGIN_ROOT/hooks/_common.sh"

input=$(cat)
sid=$(json_str "$input" session_id)
id=$(sptc_self_id "$sid")
[ -z "$id" ] && exit 0   # no perch (session not readied) -> nothing to deliver

SPT=$(spt_bin)
frames=$("$SPT" api --adapter "$ADAPTER" poll "$id" --session-id "$sid" 2>/dev/null)
[ -z "$frames" ] && exit 0

# Format for CC, preserving the sender (reply-correlation: ADR-0009/0012). Multi-frame drains are
# surfaced whole (no delimiter — spt-core F-002), never split-by-guess. See render_frames().
# UserPromptSubmit: stdout is added to the prompt context. (JSON additionalContext shape is an
# alternative — to confirm in throwaway validation which CC accepts here.)
render_frames "$frames"
exit 0
