#!/bin/sh
# sptc CI ACCEPTANCE — slice 1: spawn a REAL `claude` as the system-under-test, assert it fired
# the UserPromptSubmit hook (a deterministic digest-marker side-effect). The LLM is the SUT; this
# orchestration is deterministic and never judges model text. [impl->REQ-CI-ACCEPTANCE]
#
# SLOW LANE — env-gated. Skips cleanly (rc 0) unless SPTC_ACCEPTANCE=1 AND `claude` is on PATH, so
# the deterministic gate run stays green on hosts without claude/auth. Real-claude execution is the
# cross-process evidence for REQ-CI-ACCEPTANCE: [int->REQ-CI-ACCEPTANCE]
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/ci/acceptance/lib.sh"

if [ "${SPTC_ACCEPTANCE:-0}" != "1" ]; then
  echo "SKIP acceptance: set SPTC_ACCEPTANCE=1 to run the real-claude lane (deterministic gates unaffected)"
  exit 0
fi
if ! command -v claude >/dev/null 2>&1; then
  echo "SKIP acceptance: no \`claude\` on PATH (fleet host without the harness)"
  exit 0
fi

# Disposable identity FIRST — before any scaffold/spawn — so nothing can resolve the operator perch.
# [int->REQ-HAZARD-PERCH-COLLISION]
sptc_ci_identity "$$"          # sets+exports SPTC_CI_ID / SPT_AGENT_ID / OWL_SESSION_ID in-shell
sptc_ci_is_disposable "$SPTC_CI_ID" || { echo "FATAL: refusing to spawn under non-disposable id '$SPTC_CI_ID'"; exit 2; }
echo "acceptance: SUT identity = $SPTC_CI_ID (operator perch protected)"

work=$(mktemp -d 2>/dev/null) || { echo "FATAL: mktemp -d failed"; exit 2; }
proj="$work/proj"
digest="$work/digest.txt"
: > "$digest"
cleanup() { rm -rf "$work" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

sptc_ci_mkproject "$proj" "$digest" >/dev/null || { echo "FATAL: scaffold failed"; exit 2; }

probe="sptc-acceptance-probe-$$"
echo "acceptance: driving real claude -p in $proj (probe='$probe')"
# Drive the SUT. We assert on the hook side-effect, not stdout — model text is irrelevant.
( cd "$proj" && claude -p "$probe" >/dev/null 2>&1 ) || \
  echo "note: claude -p exited non-zero (model/auth) — asserting on hook side-effect regardless" >&2

rc=0
sptc_ci_assert "UPS hook fired in real claude" "UPS_FIRED:$probe" "$digest" || rc=1

printf '\n=== ACCEPTANCE: %s ===\n' "$([ "$rc" -eq 0 ] && echo PASS || echo FAIL)"
exit "$rc"
