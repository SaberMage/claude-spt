# shellcheck shell=sh
# sptc hook common helpers — sourced by each hook wrapper.
# DRAFT (pending throwaway-CC validation: Windows-shell, env-file timing, whoami-in-hook).
# spt-core is harness-agnostic; this is the CC adapter glue that maps CC hook input -> `spt api`.

ADAPTER=claude-spt

# CC spills additionalContext over ~10,000 chars to a file (dropping it from the inline context the
# agent sees). We pre-empt below this with margin for the marker + CC's own framing. Override-able
# for tests. (ADR-0002 Open #2.)
SPTC_CTX_CAP="${SPTC_CTX_CAP:-9000}"

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

# Render an `api poll` drain ($1) for CC. Canonical format: every message is a
# self-delimiting `<EVENT type="msg" from="<sender>">body</EVENT>` envelope (spt-proto::event) —
# the same grammar the live listener emits. Multi-message drains split cleanly on `</EVENT>`.
# Sender is preserved as `from=` (reply-correlation). NOTE: targets canonical <EVENT>; the current
# 0.6.0 binary still emits a `__REPLY_TO__` relic at the poll surface until the REQ-MSG-ENVELOPE
# refactor lands — finalize/validate against poll only post-refactor. [unit->REQ-UPS-INJECTION]
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

# Emit additionalContext under CC's ~10k spill threshold ($1=text, $2=cap, $3=spill_path). Under the
# cap -> emit as-is. Over -> spill the FULL text to a file the agent can Read and emit ONLY a concise
# pointer marker (never a partial inline — a head-cut would split a <sptc_messages>/<EVENT> block and
# lose a message silently). The agent reads the spill file to see everything; nothing is dropped. CC
# would otherwise spill oversized additionalContext itself, evicting it from the inline context.
# [impl->REQ-UPS-INJECTION]
sptc_cap_output() {
  _text="$1"; _cap="$2"; _spill="$3"
  [ -z "$_text" ] && return 0
  _len=$(printf '%s' "$_text" | wc -c | tr -d ' ')
  if [ "$_len" -le "$_cap" ]; then
    printf '%s' "$_text"
    return 0
  fi
  printf '%s' "$_text" > "$_spill" 2>/dev/null || _spill="(spill failed; content too large to inline)"
  printf '<sptc_overflow bytes="%s" cap="%s" spilled_to="%s">\nDelivery exceeded CC'\''s additionalContext cap. The full content (skill instructions and/or %s message bytes) was written to the file above — read it now to see everything; it is NOT inlined here to avoid silently dropping a message.\n</sptc_overflow>\n' \
    "$_len" "$_cap" "$_spill" "$_len"
}

# ── Checkpoint detection (REQ-DIST-CHECKPOINT-COMMUNE) ──────────────────────────────────────────
# A live agent requests a CHECKPOINT (self-initiated context reset) by embedding the literal
# `!!checkpoint!!` trigger in its commune. The PostToolUse hook detects it at Write-time and self-sends
# a structured signal that loops back through the translation binary's clear+wake macro. spt-core
# v0.15.0 strips the marker from the durable/pending context on ingest, so it is one-shot. The pure
# predicates below run on a single physical line (the raw hook JSON, whose content newlines are `\n`
# escapes) so the paired-marker scan works even for a multi-line commune body.

# PURE predicate: does this commune content ($1) carry the checkpoint trigger? exit 0 iff present.
# [unit->REQ-DIST-CHECKPOINT-COMMUNE]
sptc_has_checkpoint() {
  case "$1" in *'!!checkpoint!!'*) return 0 ;; *) return 1 ;; esac
}

# PURE: extract a CUSTOM wake directive from commune content ($1) — the text between the FIRST pair of
# `!!checkpoint!!` markers, trimmed. Prints nothing when there is only one marker (single = default
# wake; the translation binary supplies the default) or none. The pair must be inline (same physical
# line); a lone or unmatched marker yields the default. [unit->REQ-DIST-CHECKPOINT-COMMUNE]
sptc_checkpoint_wake() {
  _n=$(printf '%s' "$1" | grep -o '!!checkpoint!!' | wc -l | tr -d ' ')
  [ "${_n:-0}" -ge 2 ] || return 0
  printf '%s' "$1" | sed -n 's/.*!!checkpoint!!\(.*\)!!checkpoint!!.*/\1/p' | head -n1 \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

# PURE predicate: is this tool call ($1=tool_name, $2=file_path, $3=endpoint id) a Write to THIS
# agent's own commune file `<id>-commune.md`? Suffix match tolerates the JSON-escaped Windows path
# (doubled backslashes) and either separator. exit 0 iff it is. [unit->REQ-DIST-CHECKPOINT-COMMUNE]
sptc_is_commune_write() {
  [ "$1" = "Write" ] || return 1
  [ -n "$3" ] || return 1
  case "$2" in *"$3-commune.md") return 0 ;; *) return 1 ;; esac
}

# ── SessionStart agent-facing briefs (REQ-DIST-SESSIONSTART-BRIEF) ──────────────────────────────
# The hook COMPOSES adapter-string briefs into a SessionStart additionalContext block; it never
# authors agent-facing prose (single-source throughline — bodies live in [strings.briefs]). Pure
# assemblers below carry the only composition logic ({id} substitution, concat, wrapping) so they
# unit-test without spt; the impure resolvers wrap them with `spt adapter get-string`.

# Resolve a brief body by key from the adapter `[strings.briefs].<key>` (file-backed or inline).
# Empty on absent key / unregistered adapter / missing spt — caller tolerates. [impl->REQ-DIST-SESSIONSTART-BRIEF]
sptc_brief() {
  _key="$1"; [ -z "$_key" ] && return 0
  _spt="$(spt_bin)"
  "$_spt" adapter get-string "$ADAPTER" "briefs.$_key" 2>/dev/null
}

# PURE: assemble the identity (perched) block. $1=id $2=identity-body $3=messaging-body $4=roster.
# Substitutes {id} in the identity body (agent ids are [a-z0-9-] — sed-safe, no metachar risk).
# [impl->REQ-DIST-SESSIONSTART-BRIEF]
sptc_assemble_perch() {
  _id="$1"
  printf '<sptc-active-perch id="%s">\n%s\n\n%s\n\n%s\n</sptc-active-perch>' \
    "$_id" "$(printf '%s' "$2" | sed "s/{id}/$_id/g")" "$3" "$4"
}

# PURE: assemble the ring (no-perch) block. $1=messaging-body $2=roster. [impl->REQ-DIST-SESSIONSTART-BRIEF]
sptc_assemble_noperch() {
  printf '<sptc-reach>\n%s\n\n%s\n</sptc-reach>' "$1" "$2"
}

# Impure: resolve + assemble the perched-session identity brief for id $1. The live-ops block
# (commune incl --checkpoint, signoff — REQ-DIST-SKELETON-THIN/U4) is appended to the messaging block
# so a perched/live agent is briefed on upkeep proactively (the reactive /sptc:commune|signoff SKILL.md
# are now thin stubs). Composed into messaging (not a new positional) so sptc_assemble_perch + its unit
# test stay unchanged; skipped cleanly if the live-ops string is absent (older adapter).
# [impl->REQ-DIST-SESSIONSTART-BRIEF] [impl->REQ-DIST-SKELETON-THIN]
sptc_perch_brief() {
  _msg="$(sptc_brief messaging-perch)"
  _ops="$(sptc_brief live-ops)"
  [ -n "$_ops" ] && _msg="$_msg

$_ops"
  sptc_assemble_perch "$1" "$(sptc_brief identity)" "$_msg" "$(sptc_brief endpoint-list)"
}

# Impure: resolve + assemble the no-perch ring brief. [impl->REQ-DIST-SESSIONSTART-BRIEF]
sptc_noperch_brief() {
  sptc_assemble_noperch "$(sptc_brief messaging-no-perch)" "$(sptc_brief endpoint-list)"
}

# Impure: pull the live-agent durable RESUME context for endpoint id $1 (optional session id $2) via
# `spt api psyche-download` — the spt-core v0.15.0 W5 verb that closes F-020 (claude-spt rehydrates NO
# durable context today). stdout = durable role/live/project tiers + the freshest not-yet-synthesized
# <pending-commune>/<pending-signoff> (trigger stripped core-side), to inject VERBATIM. Mirrors the
# id-scoped `api poll` auth shape (--session-id proves association; project resolves from the bound
# cwd, no --project). Empty on NO-CONTEXT (stderr) / the verb absent (pre-v0.15.0 node) / unregistered
# — caller appends nothing. Also the checkpoint re-seed fast-path. [impl->REQ-DIST-RESUME-CONTEXT]
sptc_psyche_download() {
  _id="$1"; [ -z "$_id" ] && return 0
  _psid="$2"; _spt="$(spt_bin)"
  if [ -n "$_psid" ]; then
    "$_spt" api --adapter "$ADAPTER" psyche-download "$_id" --session-id "$_psid" 2>/dev/null
  else
    "$_spt" api --adapter "$ADAPTER" psyche-download "$_id" 2>/dev/null
  fi
}

# PURE: append resume context ($2) below a SessionStart brief ($1), skipping cleanly when the resume
# is empty (NO-CONTEXT). Newline-joined so the verbatim XML resume sits below the identity brief.
# [impl->REQ-DIST-RESUME-CONTEXT]
sptc_append_resume() {
  if [ -n "$2" ]; then printf '%s\n%s' "$1" "$2"; else printf '%s' "$1"; fi
}

# PURE predicate: should this SessionStart inject a brief? Subagent sessions (agent_type set) get
# none. $1 = the stdin agent_type value (empty = a real user session). [impl->REQ-DIST-SESSIONSTART-BRIEF]
sptc_is_subagent() { [ -n "$1" ]; }

# PURE predicate: peer-presence gate for the ring brief. Reads `spt subnet status` output on stdin;
# exit 0 (peers) iff >1 non-empty line (header + >=1 subnet row). Line-count only — NEVER parses a
# column value (the columnar layout is human-formatted, not a hook contract). [impl->REQ-DIST-SESSIONSTART-BRIEF]
sptc_has_peers_lines() {
  _n=$(grep -c . 2>/dev/null)
  [ "${_n:-0}" -gt 1 ]
}

# Impure: does this node participate in any subnet (has reachable peers)? [impl->REQ-DIST-SESSIONSTART-BRIEF]
sptc_node_has_peers() {
  _spt="$(spt_bin)"
  "$_spt" subnet status 2>/dev/null | sptc_has_peers_lines
}

# PURE: JSON-escape stdin into a string value (no surrounding quotes). Escapes \ then " , tabs, CR;
# newlines become literal \n. awk so multi-line bodies survive. [impl->REQ-DIST-SESSIONSTART-BRIEF]
sptc_json_escape() {
  awk '
    BEGIN { ORS="" }
    {
      gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); gsub(/\r/, "\\r");
      if (NR > 1) printf "%s", "\\n";
      printf "%s", $0;
    }
  '
}

# Emit a SessionStart hookSpecificOutput JSON line carrying $1 as additionalContext. No-op on empty
# ($1 unset/blank → nothing to stdout, hook stays silent). [impl->REQ-DIST-SESSIONSTART-BRIEF]
sptc_emit_additional_context() {
  [ -z "$1" ] && return 0
  _esc=$(printf '%s' "$1" | sptc_json_escape)
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$_esc"
}
