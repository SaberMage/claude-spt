#!/bin/sh
# REQ-HAZARD-MSYS-PATHCONV conformance: every hook wrapper must read the CC hook payload from
# STDIN (immune to MSYS), never reconstruct message/prompt content from a /-leading positional
# argv (Git-Bash path-mangles those on Windows — see docs/KNOWN-HAZARDS.md 1.1).
# Run: sh tests/msys-hazard.sh   (exit 0 = pass).   [unit->REQ-HAZARD-MSYS-PATHCONV]
H="$(dirname "$0")/../plugin/sptc/hooks"
fail=0
for w in session-start user-prompt-submit stop session-end subagent-start subagent-stop; do
  f="$H/$w.sh"
  # Must consume the payload from stdin.
  if ! grep -q 'input=$(cat)' "$f"; then
    printf 'FAIL %s: does not read the hook payload from stdin\n' "$w"; fail=1
  fi
  # Must NOT parse prompt/message CONTENT from a positional argument.
  if grep -Eq '(prompt|msg|body|message)=("?\$[1-9])' "$f"; then
    printf 'FAIL %s: parses content from a positional argv (MSYS-unsafe)\n' "$w"; fail=1
  fi
done
[ "$fail" -eq 0 ] && { echo "MSYS-HAZARD OK"; exit 0; } || { echo "MSYS-HAZARD FAIL"; exit 1; }
