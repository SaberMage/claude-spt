#!/bin/sh
# Unit tests for the CI acceptance harness — deterministic pieces only, NO real `claude` spawned.
# Run: sh tests/acceptance-harness.sh   (exit 0 = pass).
. "$(dirname "$0")/../ci/acceptance/lib.sh"
fail=0

# ── Perch-collision guard: identity is ALWAYS overridden to a disposable id, never a live name.
# [unit->REQ-HAZARD-PERCH-COLLISION]
# Simulate inheriting the operator's identity, then mint — both vars must be displaced.
SPT_AGENT_ID=perri OWL_SESSION_ID=perri
sptc_ci_identity 7   # bare call (no $() — must mutate THIS shell)
[ "$SPTC_CI_ID" = "sptc-ci-7" ] && echo "ok   mints disposable id" || { echo "FAIL id: got [$SPTC_CI_ID]"; fail=1; }
[ "$SPT_AGENT_ID" = "sptc-ci-7" ] && echo "ok   SPT_AGENT_ID overridden" || { echo "FAIL SPT_AGENT_ID=[$SPT_AGENT_ID] not overridden"; fail=1; }
[ "$OWL_SESSION_ID" = "sptc-ci-7" ] && echo "ok   OWL_SESSION_ID overridden" || { echo "FAIL OWL_SESSION_ID=[$OWL_SESSION_ID] not overridden"; fail=1; }
[ "$SPT_AGENT_ID" != "perri" ] && echo "ok   live id displaced" || { echo "FAIL still resolves live id"; fail=1; }

# is_disposable: accepts a minted id, rejects any live name.
sptc_ci_is_disposable "sptc-ci-7" && echo "ok   accepts disposable" || { echo "FAIL rejected disposable"; fail=1; }
sptc_ci_is_disposable "perri" && { echo "FAIL accepted live id 'perri'"; fail=1; } || echo "ok   rejects live id"
sptc_ci_is_disposable "" && { echo "FAIL accepted empty id"; fail=1; } || echo "ok   rejects empty id"

# ── Scaffold: builds settings.json + a stdin-reading (never argv) UPS hook fixture.
work=$(mktemp -d) || { echo "FAIL mktemp"; exit 1; }
trap 'rm -rf "$work"' EXIT INT TERM
proj="$work/p"; digest="$work/d.txt"
sptc_ci_mkproject "$proj" "$digest" >/dev/null
[ -f "$proj/.claude/settings.json" ] && echo "ok   scaffold writes settings.json" || { echo "FAIL no settings.json"; fail=1; }
[ -f "$proj/.claude/hooks/ups-digest.sh" ] && echo "ok   scaffold writes UPS hook" || { echo "FAIL no UPS hook"; fail=1; }
grep -q 'UserPromptSubmit' "$proj/.claude/settings.json" && echo "ok   settings wires UserPromptSubmit" || { echo "FAIL UPS not wired"; fail=1; }
# Fixture hook reads stdin, not a /-leading argv (KH 1.1 immunity).
grep -q 'input=$(cat)' "$proj/.claude/hooks/ups-digest.sh" && echo "ok   fixture reads stdin (MSYS-safe)" || { echo "FAIL fixture not stdin-driven"; fail=1; }

# Fixture actually produces the digest marker when fed a real CC-shaped payload on stdin.
printf '%s' '{"session_id":"x","prompt":"hello-probe"}' | sh "$proj/.claude/hooks/ups-digest.sh"
sptc_ci_assert "fixture emits digest marker" "UPS_FIRED:hello-probe" "$digest" >/dev/null \
  && echo "ok   fixture emits digest marker" || { echo "FAIL fixture no marker"; fail=1; }

# ── Assert helper: negative case (missing needle) must FAIL, not false-pass.
if sptc_ci_assert "neg" "NOPE" "$digest" >/dev/null; then echo "FAIL assert false-passed"; fail=1; else echo "ok   assert fails on missing needle"; fi

# ── Orchestrator is env-gated: without SPTC_ACCEPTANCE it skips cleanly (rc 0), spawns no claude.
out=$(SPTC_ACCEPTANCE=0 sh "$(dirname "$0")/../ci/acceptance/run-acceptance.sh" 2>&1); orc=$?
{ [ "$orc" -eq 0 ] && printf '%s' "$out" | grep -q 'SKIP acceptance'; } \
  && echo "ok   orchestrator env-gate skips clean" || { echo "FAIL env-gate: rc=$orc out=[$out]"; fail=1; }

[ "$fail" -eq 0 ] && { echo "ACCEPTANCE-HARNESS OK"; exit 0; } || { echo "ACCEPTANCE-HARNESS FAIL"; exit 1; }
