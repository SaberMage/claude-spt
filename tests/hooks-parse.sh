#!/bin/sh
# Unit tests for the sptc hook parsing glue (pure functions; no spt/CC needed).
# Run: sh tests/hooks-parse.sh   (exit 0 = pass)
. "$(dirname "$0")/../plugin/sptc/hooks/_common.sh"

fail=0
check() { # check <label> <expected> <actual>
  if [ "$2" = "$3" ]; then printf 'ok   %s\n' "$1"
  else printf 'FAIL %s\n  expected: [%s]\n  actual:   [%s]\n' "$1" "$2" "$3"; fail=1; fi
}

# --- json_str: top-level CC hook-input fields ---  [unit->REQ-DIST-HOOKS-API]
J='{"session_id":"sess-abc123","transcript_path":"/x","source":"startup","model":"m"}'
check "json_str session_id" "sess-abc123" "$(json_str "$J" session_id)"
check "json_str source"     "startup"     "$(json_str "$J" source)"
check "json_str prompt"      "/sptc:send doyle" \
  "$(json_str '{"session_id":"s1","prompt":"/sptc:send doyle"}' prompt)"
check "json_str missing key" "" "$(json_str "$J" nope)"

# --- sptc_unescape: <br> -> newline, entities, &amp; LAST --- [unit->REQ-UPS-INJECTION]
check "unescape br+entities" \
  "$(printf 'a <b>\n"c" & &lt;')" \
  "$(sptc_unescape 'a &lt;b&gt;<br>&quot;c&quot; &amp; &amp;lt;')"

# --- render_frames: canonical <EVENT> envelope (ADR-0020) --- [unit->REQ-UPS-INJECTION]
# Named single, <br>-escaped multiline body, sender preserved.
named=$(render_frames '<EVENT type="msg" from="doyle">hello<br>world</EVENT>')
check "render named <EVENT>" \
  "$(printf '<sptc_messages from="doyle">\nhello\nworld\n</sptc_messages>')" "$named"

# Entity-escaped body decodes.
ent=$(render_frames '<EVENT type="msg" from="kit">a &lt;tag&gt; &amp; b</EVENT>')
check "render entity body" \
  "$(printf '<sptc_messages from="kit">\na <tag> & b\n</sptc_messages>')" "$ent"

# Multi-message drain: two self-delimiting envelopes -> two rendered blocks.
multi=$(render_frames '<EVENT type="msg" from="a">one</EVENT><EVENT type="msg" from="b">two</EVENT>')
check "render multi-message" \
  "$(printf '<sptc_messages from="a">\none\n</sptc_messages>\n<sptc_messages from="b">\ntwo\n</sptc_messages>')" \
  "$multi"

# Envelope without a from attr -> anonymous rendering.
anon=$(render_frames '<EVENT type="msg">sys note</EVENT>')
check "render no-from" "$(printf '<sptc_messages>\nsys note\n</sptc_messages>')" "$anon"

# Empty drain -> no output.
check "render empty" "" "$(render_frames '')"

# --- sptc_skill_key: detect /sptc:<skill> in a slash-command prompt --- [unit->REQ-UPS-INJECTION]
check "skill_key bare"        "ready"  "$(sptc_skill_key '/sptc:ready')"
check "skill_key with args"   "send"   "$(sptc_skill_key '/sptc:send doyle hi')"
check "skill_key leading ws"  "setup"  "$(sptc_skill_key '   /sptc:setup')"
check "skill_key hyphenated"  "list-agents" "$(sptc_skill_key '/sptc:list-agents')"
check "skill_key mid-prose"   ""       "$(sptc_skill_key 'please run /sptc:ready for me')"
check "skill_key other ns"    ""       "$(sptc_skill_key '/other:ready')"
check "skill_key not a cmd"   ""       "$(sptc_skill_key 'ready set go')"
check "skill_key empty"       ""       "$(sptc_skill_key '')"

# --- sptc_register_verb: SessionStart bind/seed/boundary branch --- [unit->REQ-DIST-SHORTCUT-BASENAME]
# spt-hosted (endpoint id injected) -> bind; harness-hosted (no id) -> seed; clear/compact -> boundary.
unset SPT_ENDPOINT_ID
check "verb harness-hosted startup"   "seed"     "$(sptc_register_verb startup)"
check "verb harness-hosted empty src" "seed"     "$(sptc_register_verb '')"
check "verb boundary clear"           "boundary" "$(sptc_register_verb clear)"
check "verb boundary compact"         "boundary" "$(sptc_register_verb compact)"
SPT_ENDPOINT_ID=cc-7; export SPT_ENDPOINT_ID
check "verb spt-hosted startup -> bind" "bind"     "$(sptc_register_verb startup)"
# A /clear inside an spt-hosted session still rebinds via boundary (never re-binds fresh).
check "verb spt-hosted clear -> boundary" "boundary" "$(sptc_register_verb clear)"
unset SPT_ENDPOINT_ID

# --- sptc_cap_output: additionalContext spill guard (ADR-0002 Open #2) --- [unit->REQ-UPS-INJECTION]
spill="${TMPDIR:-/tmp}/sptc-cap-$$.txt"
rm -f "$spill"
check "cap under -> passthrough verbatim" "small body" "$(sptc_cap_output 'small body' 9000 "$spill")"
check "cap under -> no spill written"     "absent"     "$([ -f "$spill" ] && echo present || echo absent)"

over=$(sptc_cap_output 'abcdefghij' 5 "$spill")   # 10 bytes > cap 5
case "$over" in *'<sptc_overflow'*) m=ok ;; *) m=no ;; esac
check "cap over -> emits overflow marker"  "ok"         "$m"
check "cap over -> full body spilled"      "abcdefghij" "$(cat "$spill" 2>/dev/null)"
case "$over" in *abcdefghij*) leak=leaked ;; *) leak=clean ;; esac
check "cap over -> body not inlined"       "clean"      "$leak"
check "cap empty -> no output"             ""           "$(sptc_cap_output '' 5 "$spill")"
rm -f "$spill"

[ "$fail" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "FAILURES"; exit 1; }
