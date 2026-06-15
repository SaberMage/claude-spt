#!/bin/sh
# SessionStart: ensure spt-core installed, seed the perch (or rebind on clear/compact),
# and persist session env so whoami + per-prompt hooks resolve. Non-blocking (never `listen`).
# [impl->REQ-DIST-HOOKS-API]
. "$CLAUDE_PLUGIN_ROOT/hooks/_common.sh"

input=$(cat)
sid=$(json_str "$input" session_id)
src=$(json_str "$input" source)

# Invisible-installer: bootstrap spt-core if absent (no-op when present).
sh "$CLAUDE_PLUGIN_ROOT/bootstrap.sh" >/dev/null 2>&1 || true
SPT=$(spt_bin)

case "$src" in
  clear|compact)
    id=$(sptc_self_id "$sid")
    [ -n "$id" ] && "$SPT" api --adapter "$ADAPTER" boundary "$src" "$id" \
      --to-session-id "$sid" >/dev/null 2>&1 || true
    ;;
  *)
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
