#!/bin/sh
# UserPromptSubmit: two jobs on the same hook (ADR-0002 — UPS fires on a `/sptc:X` slash-command
# with the token intact, validated 2026-06-15). Both write to stdout = CC additionalContext:
#   1. SKILL-INJECTION — detect `/sptc:<skill>` in the prompt and inject that skill's operative
#      instructions from the adapter `[strings.skills].<skill>` (the thin SKILL.md stays a stub).
#   2. MESSAGE-DRAIN — `api poll` the perch and surface delivered <EVENT> messages.
# [impl->REQ-UPS-INJECTION]
. "$CLAUDE_PLUGIN_ROOT/hooks/_common.sh"

input=$(cat)
sid=$(json_str "$input" session_id)

# 1. Skill-injection runs BEFORE the perch check — skills like /sptc:whoami and /sptc:setup are
#    valid without a readied perch (setup even runs before spt exists). No-op if not a sptc command.
prompt=$(json_str "$input" prompt)
sptc_inject_skill "$(sptc_skill_key "$prompt")"

# 2. Message-drain needs a perch. No perch (session not readied) -> nothing to deliver.
id=$(sptc_self_id "$sid")
[ -z "$id" ] && exit 0

SPT=$(spt_bin)
frames=$("$SPT" api --adapter "$ADAPTER" poll "$id" --session-id "$sid" 2>/dev/null)
[ -z "$frames" ] && exit 0

# Format for CC, preserving the sender (reply-correlation: ADR-0009/0012). render_frames parses
# the self-delimiting <EVENT> envelope (ADR-0020) — multi-message drains split on </EVENT>.
render_frames "$frames"
exit 0
