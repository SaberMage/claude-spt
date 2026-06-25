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

# --- render_frames: canonical <EVENT> envelope --- [unit->REQ-UPS-INJECTION]
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

# --- SessionStart briefs: pure composition --- [unit->REQ-DIST-SESSIONSTART-BRIEF]
# assemble_perch: {id} substitution + block structure.
pb=$(sptc_assemble_perch "perri" 'you are {id}.' 'send body' 'roster line')
check "assemble_perch structure+subst" \
  "$(printf '<sptc-active-perch id="perri">\nyou are perri.\n\nsend body\n\nroster line\n</sptc-active-perch>')" \
  "$pb"
case "$pb" in *'{id}'*) leftover=present ;; *) leftover=clean ;; esac
check "assemble_perch no {id} leftover" "clean" "$leftover"
# Every {id} occurrence is substituted (global).
multi_id=$(sptc_assemble_perch "kit" 'a {id} b {id}' 'm' 'r')
case "$multi_id" in *'a kit b kit'*) g=ok ;; *) g=no ;; esac
check "assemble_perch global subst" "ok" "$g"

# assemble_noperch: ring block structure (no id).
nb=$(sptc_assemble_noperch 'ring body' 'roster line')
check "assemble_noperch structure" \
  "$(printf '<sptc-reach>\nring body\n\nroster line\n</sptc-reach>')" "$nb"

# is_subagent: empty -> real session (inject); set -> subagent (skip).
check "is_subagent empty -> no"   "no"  "$(sptc_is_subagent ''               && echo yes || echo no)"
check "is_subagent set -> yes"    "yes" "$(sptc_is_subagent 'general-purpose' && echo yes || echo no)"

# has_peers_lines: >1 non-empty line on `subnet status` stdin = peers present.
check "peers: header+row -> yes" "yes" "$(printf 'SUBNET NODES ENDPOINTS\nSPT_DEV 3 4\n' | sptc_has_peers_lines && echo yes || echo no)"
check "peers: single line -> no" "no"  "$(printf 'no subnets\n'                            | sptc_has_peers_lines && echo yes || echo no)"
check "peers: empty -> no"       "no"  "$(printf ''                                          | sptc_has_peers_lines && echo yes || echo no)"

# --- SessionStart briefs: JSON encode + emit --- [unit->REQ-DIST-SESSIONSTART-BRIEF]
check "json_escape quotes"    'say \"hi\"' "$(printf '%s' 'say "hi"' | sptc_json_escape)"
check "json_escape backslash" 'a\\b'       "$(printf '%s' 'a\b'      | sptc_json_escape)"
check "json_escape newline"   'a\nb'       "$(printf 'a\nb'          | sptc_json_escape)"

check "emit empty -> silent" "" "$(sptc_emit_additional_context '')"
check "emit json shape" \
  '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"hi \"x\""}}' \
  "$(sptc_emit_additional_context 'hi "x"')"
check "emit json newline-escaped" \
  '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"a\nb"}}' \
  "$(sptc_emit_additional_context "$(printf 'a\nb')")"

# --- checkpoint detection: trigger presence, custom-wake extraction, commune-write guard ---
# [unit->REQ-DIST-CHECKPOINT-COMMUNE]
check "has_checkpoint single"  "yes" "$(sptc_has_checkpoint 'delta ... !!checkpoint!!'        && echo yes || echo no)"
check "has_checkpoint pair"    "yes" "$(sptc_has_checkpoint '!!checkpoint!! wake !!checkpoint!!' && echo yes || echo no)"
check "has_checkpoint absent"  "no"  "$(sptc_has_checkpoint 'an ordinary commune delta'        && echo yes || echo no)"
check "has_checkpoint empty"   "no"  "$(sptc_has_checkpoint ''                                  && echo yes || echo no)"

# Single marker -> no custom wake (binary applies the default).
check "wake single -> default(empty)" "" "$(sptc_checkpoint_wake 'work ... !!checkpoint!!')"
# Paired markers -> the trimmed inner text is the custom wake.
check "wake pair -> custom" "Resume T2c now" \
  "$(sptc_checkpoint_wake 'body !!checkpoint!! Resume T2c now !!checkpoint!! more')"
# Pair embedded in a realistic single-line JSON content blob.
check "wake pair in json blob" "wire the hook" \
  "$(sptc_checkpoint_wake '{"content":"delta\n!!checkpoint!! wire the hook !!checkpoint!!\nend"}')"
check "wake none -> empty"     "" "$(sptc_checkpoint_wake 'no markers here')"

# commune-write guard: Write to <id>-commune.md only (tolerates JSON-escaped Windows path).
check "commune_write match unix"  "yes" \
  "$(sptc_is_commune_write Write '/home/x/.claude/perri-commune.md' perri && echo yes || echo no)"
check "commune_write match win"   "yes" \
  "$(sptc_is_commune_write Write 'C:\\\\Users\\\\d\\\\.claude\\\\perri-commune.md' perri && echo yes || echo no)"
check "commune_write wrong file"  "no"  \
  "$(sptc_is_commune_write Write '/home/x/.claude/notes.md' perri && echo yes || echo no)"
check "commune_write wrong id"    "no"  \
  "$(sptc_is_commune_write Write '/home/x/.claude/doyle-commune.md' perri && echo yes || echo no)"
check "commune_write not Write"   "no"  \
  "$(sptc_is_commune_write Edit '/home/x/.claude/perri-commune.md' perri && echo yes || echo no)"
check "commune_write empty id"    "no"  \
  "$(sptc_is_commune_write Write '/home/x/.claude/perri-commune.md' '' && echo yes || echo no)"

# --- resume-context append: skip cleanly on NO-CONTEXT (REQ-DIST-RESUME-CONTEXT) ---
# [unit->REQ-DIST-RESUME-CONTEXT]
# Non-empty resume -> appended below the brief, newline-joined (verbatim XML sits under the identity).
check "append resume present" \
  "$(printf '<brief/>\n<live-context>ctx</live-context>')" \
  "$(sptc_append_resume '<brief/>' '<live-context>ctx</live-context>')"
# Empty resume (NO-CONTEXT) -> brief unchanged, no trailing newline injected.
check "append resume empty -> brief verbatim" "<brief/>" "$(sptc_append_resume '<brief/>' '')"
# Both empty -> empty.
check "append resume both empty" "" "$(sptc_append_resume '' '')"

# --- PreToolUse mid-turn reachability wiring (F-021) --- [unit->REQ-DIST-PRETOOL-POLL]
# The busy/idle turn-state lifecycle + the PreToolUse deferred-drain. Structural (the hook files +
# manifest declaration are the artifacts; the api commands run against a live perch at the int tier).
HK="$(dirname "$0")/../plugin/sptc/hooks"
MAN="$(dirname "$0")/../adapter/claude-spt.toml"
grep -q '"PreToolUse"' "$HK/hooks.json" && r=yes || r=no
check "hooks.json declares PreToolUse" "yes" "$r"
grep -q 'pre-tool-use.sh' "$HK/hooks.json" && r=yes || r=no
check "PreToolUse routes to pre-tool-use.sh" "yes" "$r"
grep -q 'poll .*--include-deferred' "$HK/pre-tool-use.sh" && r=yes || r=no
check "pre-tool-use drains deferred (api poll --include-deferred)" "yes" "$r"
# PreToolUse also marks busy (covers Monitor-triggered turns with no UserPromptSubmit).
grep -q 'state busy' "$HK/pre-tool-use.sh" && r=yes || r=no
check "pre-tool-use marks busy (non-user turn-start fallback)" "yes" "$r"
# And it sets busy BEFORE draining (so a message landing mid-drain also defers).
awk '/state busy/{b=NR} /poll .*--include-deferred/{p=NR} END{exit !(b && p && b<p)}' "$HK/pre-tool-use.sh" && r=yes || r=no
check "pre-tool-use sets busy before the drain" "yes" "$r"
grep -q 'state busy' "$HK/user-prompt-submit.sh" && r=yes || r=no
check "UPS marks perch busy at turn-start (api state busy)" "yes" "$r"
grep -q 'poll .*--include-deferred' "$HK/user-prompt-submit.sh" && r=yes || r=no
check "UPS drain includes deferred" "yes" "$r"
grep -q 'state idle' "$HK/stop.sh" && r=yes || r=no
check "Stop marks perch idle at turn-end (api state idle)" "yes" "$r"
grep -q '^\[hooks\.PreToolUse\]' "$MAN" && r=yes || r=no
check "manifest declares [hooks.PreToolUse]" "yes" "$r"

# --- U4: reactive-skill thinning + live-ops brief --- [unit->REQ-DIST-SKELETON-THIN]
# commune/send/signoff prose moved OUT of the plugin SKILL.md INTO adapter strings (the live-ops brief
# + the go-live body), so it rides `spt adapter update`; the SKILL.md are now thin stubs.
BR="$(dirname "$0")/../adapter/strings/briefs"
SK="$(dirname "$0")/../plugin/sptc/skills"
CM="$(dirname "$0")/../plugin/sptc/hooks/_common.sh"
LV="$(dirname "$0")/../adapter/strings/skills/live.md"
grep -q 'commune' "$BR/live-ops.md" && grep -q '!!checkpoint!!' "$BR/live-ops.md" && grep -q 'endpoint shutdown' "$BR/live-ops.md" && r=yes || r=no
check "live-ops brief carries commune+checkpoint+signoff" "yes" "$r"
grep -q 'live-ops' "$CM" && r=yes || r=no
check "sptc_perch_brief composes live-ops" "yes" "$r"
grep -q 'live-ops = { file' "$MAN" && r=yes || r=no
check "manifest registers briefs.live-ops" "yes" "$r"
grep -q 'commune.md' "$LV" && grep -q '!!checkpoint!!' "$LV" && r=yes || r=no
check "go-live body inlines commune+checkpoint (no SessionStart re-fire in-session)" "yes" "$r"
for s in commune signoff send; do
  grep -q 'thin skeleton' "$SK/$s/SKILL.md" && r=yes || r=no
  check "$s SKILL.md is a thin stub (prose rides adapter)" "yes" "$r"
done
# The pre-U4 full step-by-step bodies must be gone from the stubs (not just supplemented).
grep -q 'Normal commune' "$SK/commune/SKILL.md" && r=present || r=absent
check "commune SKILL.md full body removed" "absent" "$r"

[ "$fail" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "FAILURES"; exit 1; }
