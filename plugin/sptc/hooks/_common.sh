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

# Decide the SessionStart registration verb for this spawn ($1 = CC hook `source`; reads env
# $SPT_ENDPOINT_ID). Pure — no spt/CC. [impl->REQ-DIST-SHORTCUT-BASENAME]
#   boundary — a /clear or /compact within a live session (rebind the perch to the new session id)
#   bind     — spt-hosted: `spt endpoint run` spawned us via [session.self] + injected the endpoint
#              id into $SPT_ENDPOINT_ID; the perch already exists, self-register post-spawn
#   seed     — harness-hosted: user-launched CC; record an ephemeral seed for /sptc:ready|live
sptc_register_verb() {
  case "$1" in
    clear|compact) printf boundary ;;
    *) if [ -n "${SPT_ENDPOINT_ID:-}" ]; then printf bind; else printf seed; fi ;;
  esac
}

# Resolve this session's perch id via spt whoami (off $OWL_SESSION_ID / $SPT_AGENT_ID).
# Empty => no perch yet (session never readied) => caller no-ops.
sptc_self_id() {
  _sid="$1"; _spt="$(spt_bin)"
  OWL_SESSION_ID="${OWL_SESSION_ID:-$_sid}" "$_spt" whoami 2>/dev/null | head -n1
}

# Decode an spt envelope body to plain text: literal `<br>` -> newline, then HTML entities
# (&lt; &gt; &quot; then &amp; LAST, to avoid double-decoding). Exactly the live-agent
# body-parsing rule (spt-proto::event, ADR-0001 grammar).
sptc_unescape() {
  printf '%s' "$1" | sed \
    -e 's/<br>/\
/g' \
    -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&quot;/"/g' -e 's/&amp;/\&/g'
}

# Render an `api poll` drain ($1) for CC. Canonical format (ADR-0020): every message is a
# self-delimiting `<EVENT type="msg" from="<sender>">body</EVENT>` envelope (spt-proto::event) —
# the same grammar the live listener emits. Multi-message drains split cleanly on `</EVENT>`.
# Sender is preserved as `from=` (reply-correlation). NOTE: targets canonical <EVENT>; the current
# 0.6.0 binary still emits a `__REPLY_TO__` relic at the poll surface until the REQ-MSG-ENVELOPE
# refactor lands (ADR-0020) — finalize/validate against poll only post-refactor. [unit->REQ-UPS-INJECTION]
render_frames() {
  _in="$1"
  [ -z "$_in" ] && return 0
  # Normalise to one <EVENT>…</EVENT> per line (body newlines are <br>-escaped, so each envelope
  # is single-line), then parse each.
  printf '%s' "$_in" | sed 's#</EVENT>#</EVENT>\
#g' | while IFS= read -r _ev; do
    case "$_ev" in
      *"<EVENT"*"</EVENT>"*) ;;
      *) continue ;;
    esac
    _sender=$(printf '%s' "$_ev" | sed -n 's/.*<EVENT[^>]* from="\([^"]*\)".*/\1/p')
    _raw=$(printf '%s' "$_ev" | sed -n 's#.*<EVENT[^>]*>\(.*\)</EVENT>.*#\1#p')
    _body=$(sptc_unescape "$_raw")
    if [ -n "$_sender" ]; then
      printf '<sptc_messages from="%s">\n%s\n</sptc_messages>\n' "$_sender" "$_body"
    else
      printf '<sptc_messages>\n%s\n</sptc_messages>\n' "$_body"
    fi
  done
}

# Extract the skill name from a `/sptc:<skill>` slash-command prompt ($1=prompt). UPS fires on a
# slash-command with the token intact (ADR-0002 validation 2026-06-15: `prompt:"/sptc:send doyle"`),
# so the wrapper detects the command here. Leading-only (after optional whitespace) to avoid firing
# on prose that merely mentions `/sptc:x` mid-sentence. Empty => not a sptc slash-command.
# [unit->REQ-UPS-INJECTION]
sptc_skill_key() {
  printf '%s' "$1" | sed -n 's#^[[:space:]]*/sptc:\([a-z][a-z0-9-]*\).*#\1#p' | head -n1
}

# Inject a skill's operative instructions ($1=skill name) as additionalContext. Resolves the
# file-backed/inline body from the adapter `[strings.skills].<skill>` via `spt adapter get-string`
# (F-003: pointer values resolve to file contents at read time). No-op (silent) if spt is absent,
# the adapter is unregistered, or the key is unset — the thin SKILL.md skeleton still loaded by CC
# is the floor. The injected body is what the agent follows for this `/sptc:<skill>` invocation.
# [impl->REQ-UPS-INJECTION]
sptc_inject_skill() {
  _skill="$1"; [ -z "$_skill" ] && return 0
  _spt="$(spt_bin)"
  _body=$("$_spt" adapter get-string "$ADAPTER" "skills.$_skill" 2>/dev/null) || return 0
  [ -z "$_body" ] && return 0
  printf '<sptc_skill name="%s">\n%s\n</sptc_skill>\n' "$_skill" "$_body"
}
