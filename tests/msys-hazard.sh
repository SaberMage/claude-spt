#!/bin/sh
# REQ-HAZARD-MSYS-PATHCONV conformance (D1 architecture). The CC hook payload — which can contain
# /-leading content (e.g. a prompt "/sptc:send doyle") — must reach the handler via STDIN (immune to
# MSYS), never as a positional argv (Git-Bash path-mangles a /-leading argv on Windows — see
# docs/KNOWN-HAZARDS.md 1.1). After D1 the only argv passed anywhere is the CC EVENT NAME (SessionStart,
# …) + the numeric --host-pid — never message/prompt content, and never /-leading.
# Run: sh tests/msys-hazard.sh   (exit 0 = pass).   [unit->REQ-HAZARD-MSYS-PATHCONV]
ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
HK="$ROOT/plugin/sptc/hooks"
HOOKRS="$ROOT/tools/claude-spt/src/hook.rs"
fail=0
yn() { [ "$1" -eq 0 ] && echo yes || echo no; }

# 1. hooks.json passes dispatch.sh only a bare, non-/-leading CC event-name token (no payload content).
#    Every `dispatch.sh <token>` token must be alphabetic (an event name), never /-leading.
bad_tokens=$(grep -oE 'dispatch\.sh\\?" [^"]+' "$HK/hooks.json" | sed 's#.*dispatch\.sh\\\?" ##' | grep -Ec '^[A-Za-z]' )
tot_tokens=$(grep -oE 'dispatch\.sh\\?" [^"]+' "$HK/hooks.json" | wc -l | tr -d ' ')
if [ "$bad_tokens" -ne "$tot_tokens" ] || [ "$tot_tokens" -eq 0 ]; then
  printf 'FAIL hooks.json: a dispatch token is not a bare event name (%s/%s alphabetic)\n' "$bad_tokens" "$tot_tokens"; fail=1
fi
if grep -qE 'dispatch\.sh\\?" +/' "$HK/hooks.json"; then
  printf 'FAIL hooks.json: a /-leading positional token is passed to dispatch.sh (MSYS-unsafe)\n'; fail=1
fi

# 2. dispatch.sh must NOT read the payload (no `cat`) — it inherits stdin straight through to the
#    binary — and must NOT reconstruct content from a positional argv ($1 is the event name only).
if grep -qE '\$\(\s*cat\b' "$HK/dispatch.sh"; then
  printf 'FAIL dispatch.sh: reads stdin itself (must pass it through to the binary)\n'; fail=1
fi
if grep -Eq '(prompt|msg|body|message|content|file_path)=("?\$[1-9])' "$HK/dispatch.sh"; then
  printf 'FAIL dispatch.sh: parses payload content from a positional argv (MSYS-unsafe)\n'; fail=1
fi

# 3. The binary reads the CC payload from STDIN and parses every field off that parsed object — never
#    from argv (which only carries the event name + --host-pid).
grep -q 'stdin().read_to_string' "$HOOKRS" && r=0 || r=1
[ "$r" -eq 0 ] || { printf 'FAIL hook.rs: does not read the CC payload from stdin\n'; fail=1; }
# The argv loop handles only --host-pid; the payload fields come from the parsed stdin Value (field/nested).
grep -q 'serde_json::from_str' "$HOOKRS" && r=0 || r=1
[ "$r" -eq 0 ] || { printf 'FAIL hook.rs: does not parse the stdin payload as JSON\n'; fail=1; }

[ "$fail" -eq 0 ] && { echo "MSYS-HAZARD OK"; exit 0; } || { echo "MSYS-HAZARD FAIL"; exit 1; }
