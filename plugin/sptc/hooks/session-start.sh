#!/bin/sh
# SessionStart: ensure spt-core installed, then register the perch — bind (spt-hosted, broker
# spawned us via [session.self] + injected $SPT_ENDPOINT_ID), seed (harness-hosted, user-launched
# CC), or boundary-rebind (clear/compact) — and persist session env so whoami + per-prompt hooks
# resolve. Non-blocking (never `listen`).
# [impl->REQ-DIST-HOOKS-API]
. "$CLAUDE_PLUGIN_ROOT/hooks/_common.sh"

input=$(cat)
sid=$(json_str "$input" session_id)
src=$(json_str "$input" source)

# Invisible-installer: bootstrap spt-core if absent (no-op when present).
sh "$CLAUDE_PLUGIN_ROOT/bootstrap.sh" >/dev/null 2>&1 || true
SPT=$(spt_bin)

case "$(sptc_register_verb "$src")" in
  boundary)
    id=$(sptc_self_id "$sid")
    [ -n "$id" ] && "$SPT" api --adapter "$ADAPTER" boundary "$src" "$id" \
      --to-session-id "$sid" >/dev/null 2>&1 || true
    ;;
  bind)
    # spt-hosted: `spt endpoint run` spawned us into the broker PTY and injected the endpoint id via
    # [env.SPT_ENDPOINT_ID]. The perch already exists — self-register post-spawn by binding our
    # discovered CC session id, NOT seed (no seed file in this path). `bind` is an ESTABLISHING call:
    # the broker parentage IS the credential (auth intrinsic), so --set-session-id alone, no proof
    # token — confirmed by doyle 2026-06-15 (harness-contract/api.md "Auth is intrinsic"). Later
    # mutating calls prove association with --session-id "$sid" against the record bind wrote.
    "$SPT" api --adapter "$ADAPTER" bind "$SPT_ENDPOINT_ID" \
      --set-session-id "$sid" >/dev/null 2>&1 || true
    ;;
  seed)
    # harness-hosted (seed→listen path): user-launched CC. Record the seed for /sptc:ready|live.
    # ADAPTER-AGNOSTIC since spt-core v0.9.0 (PREP-4): NO --adapter — `api listen`/`poll` resolve the
    # owning adapter from this seed's parent pid via [adapter] host_binaries = ["claude"] (the legacy-
    # parity bare flow). $PPID is the CC host process (basename `claude`), the host_binaries match-key.
    # (bind/boundary above keep their explicit --adapter override — sanctioned, valid on 0.9.0.)
    "$SPT" api seed --pid "$PPID" --session-id "$sid" >/dev/null 2>&1 || true
    ;;
esac

# Persist for the rest of the session (whoami + per-prompt hooks read these).
if [ -n "$CLAUDE_ENV_FILE" ]; then
  {
    printf 'OWL_SESSION_ID=%s\n' "$sid"
    printf 'SPT_ADAPTER=%s\n' "$ADAPTER"
  } >> "$CLAUDE_ENV_FILE"
fi

# Relay an agent-facing brief as additionalContext (REQ-DIST-SESSIONSTART-BRIEF). Perched sessions
# (bind/boundary — an id already exists) get the identity brief: who they are + perch-is-live +
# how to message. No-perch seeds on a node WITH subnet peers get the ring brief (how to reach others
# without a perch). Seeds with no peers, and subagent (agent_type) sessions, get nothing. All prose
# is adapter-string-backed; this hook only selects + composes. [impl->REQ-DIST-SESSIONSTART-BRIEF]
if ! sptc_is_subagent "$(json_str "$input" agent_type)"; then
  brief=""
  case "$(sptc_register_verb "$src")" in
    bind|boundary)
      # id: the spt-hosted endpoint id if injected, else resolve our perch via whoami.
      bid="${SPT_ENDPOINT_ID:-$(sptc_self_id "$sid")}"
      if [ -n "$bid" ]; then
        brief=$(sptc_perch_brief "$bid")
        # Durable RESUME context (F-020 fix, REQ-DIST-RESUME-CONTEXT): pull the agent's role/live/
        # project tiers + freshest pending commune/signoff and inject it VERBATIM below the identity
        # brief. Fires on a fresh spt-hosted bind AND on a post-/clear boundary — boundary IS the
        # checkpoint re-seed path, where the just-cleared agent rebuilds from its latest commune. The
        # `api boundary` rotation above is unchanged; this is an additive context pull. Empty on
        # NO-CONTEXT or a pre-v0.15.0 node (verb absent) -> nothing appended.
        brief=$(sptc_append_resume "$brief" "$(sptc_psyche_download "$bid" "$sid")")
      fi
      ;;
    seed)
      sptc_node_has_peers && brief=$(sptc_noperch_brief)
      ;;
  esac
  sptc_emit_additional_context "$brief"
fi
exit 0
