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

# --- render_frames: named sender (multiline body preserved, sender surfaced) --- [unit->REQ-UPS-INJECTION]
named=$(render_frames "$(printf '__REPLY_TO__:doyle\nhello\nworld')")
check "render named" \
  "$(printf '<sptc_messages from="doyle">\nhello\nworld\n</sptc_messages>')" "$named"

# --- render_frames: anonymous (bare body, no header) ---
anon=$(render_frames "bare body")
check "render anon" "$(printf '<sptc_messages>\nbare body\n</sptc_messages>')" "$anon"

# --- render_frames: empty drain -> no output ---
check "render empty" "" "$(render_frames "")"

[ "$fail" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "FAILURES"; exit 1; }
