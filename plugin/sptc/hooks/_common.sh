# shellcheck shell=sh
# sptc hook common helpers — sourced by each hook wrapper.
# DRAFT (pending throwaway-CC validation: Windows-shell, env-file timing, whoami-in-hook).
# spt-core is harness-agnostic; this is the CC adapter glue that maps CC hook input -> `spt api`.

ADAPTER=claude-spt

# Resolve the spt binary: PATH first (post-bootstrap), then known install locations.
spt_bin() {
  if command -v spt >/dev/null 2>&1; then printf 'spt'; return 0; fi
  for p in \
    "$HOME/.local/bin/spt" \
    "$LOCALAPPDATA/spt-core/bin/spt.exe" \
    "$HOME/AppData/Local/spt-core/bin/spt.exe"; do
    [ -x "$p" ] && { printf '%s' "$p"; return 0; }
  done
  printf 'spt'  # last resort; caller tolerates failure
}

# Extract a top-level string field from a flat JSON object on stdin payload ($1=json, $2=key).
# CC hook input is a flat object for the fields we need (session_id, source, prompt, agent_id).
json_str() {
  printf '%s' "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n1
}

# Resolve this session's perch id via spt whoami (off $OWL_SESSION_ID / $SPT_AGENT_ID).
# Empty => no perch yet (session never readied) => caller no-ops.
sptc_self_id() {
  _sid="$1"; _spt="$(spt_bin)"
  OWL_SESSION_ID="${OWL_SESSION_ID:-$_sid}" "$_spt" whoami 2>/dev/null | head -n1
}

# Render an `api poll` drain ($1) for CC, preserving the sender for reply-correlation.
# Frame contract (spool.rs): named = "__REPLY_TO__:<from>\n<body>", anonymous = bare body.
# SINGLE-MESSAGE only — a multi-frame drain has no delimiter (spt-core F-002), so it is surfaced
# whole rather than split; do NOT guess frame boundaries here. [unit->REQ-UPS-INJECTION]
render_frames() {
  _frames="$1"
  [ -z "$_frames" ] && return 0
  _first=$(printf '%s' "$_frames" | head -n1)
  case "$_first" in
    __REPLY_TO__:*)
      _sender=${_first#__REPLY_TO__:}
      _body=$(printf '%s' "$_frames" | sed '1d')
      printf '<sptc_messages from="%s">\n%s\n</sptc_messages>\n' "$_sender" "$_body"
      ;;
    *)
      printf '<sptc_messages>\n%s\n</sptc_messages>\n' "$_frames"
      ;;
  esac
}
