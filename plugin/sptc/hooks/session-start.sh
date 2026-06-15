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
    "$SPT" api --adapter "$ADAPTER" seed --pid "$PPID" --session-id "$sid" >/dev/null 2>&1 || true
    ;;
esac

# Persist for the rest of the session (whoami + per-prompt hooks read these).
if [ -n "$CLAUDE_ENV_FILE" ]; then
  {
    printf 'OWL_SESSION_ID=%s\n' "$sid"
    printf 'SPT_ADAPTER=%s\n' "$ADAPTER"
  } >> "$CLAUDE_ENV_FILE"
fi
exit 0
