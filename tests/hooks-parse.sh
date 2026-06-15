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

[ "$fail" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "FAILURES"; exit 1; }
