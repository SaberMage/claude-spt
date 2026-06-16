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

# Buffer both outputs so the COMBINED additionalContext is capped once (ADR-0002 Open #2) — a large
# skill body + a big drain could jointly exceed CC's spill threshold.
out=""

# 1. Skill-injection runs BEFORE the perch check — skills like /sptc:version and /sptc:setup are
#    valid without a readied perch (setup even runs before spt exists). No-op if not a sptc command.
prompt=$(json_str "$input" prompt)
out="$(sptc_inject_skill "$(sptc_skill_key "$prompt")")"

# 2. Message-drain needs a perch. No perch (session not readied) -> nothing more to deliver.
id=$(sptc_self_id "$sid")
if [ -n "$id" ]; then
  SPT=$(spt_bin)
  frames=$("$SPT" api --adapter "$ADAPTER" poll "$id" --session-id "$sid" 2>/dev/null)
  if [ -n "$frames" ]; then
    # Format for CC, preserving the sender (reply-correlation: ADR-0009/0012). render_frames parses
    # the self-delimiting <EVENT> envelope (ADR-0020) — multi-message drains split on </EVENT>.
    rendered=$(render_frames "$frames")
    [ -n "$rendered" ] && out="${out:+$out
}$rendered"
  fi
fi

# Emit under CC's additionalContext cap; oversized drains spill to a file the agent reads (no
# silent message loss). Spill path is an absolute, agent-readable location keyed by session.
spill="${HOME:-${USERPROFILE:-.}}/.claude/sptc-drain-${sid:-unknown}.txt"
sptc_cap_output "$out" "$SPTC_CTX_CAP" "$spill"
exit 0
