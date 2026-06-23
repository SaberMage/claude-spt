#!/bin/sh
# Regression seed for F-017 — the LATENT multi-subnet bringup gap (doyle's ADRs 0026/0027 milestone,
# v0.13.3+). NOT a version regression: it is established home-assignment policy that only BITES once a
# node holds 2+ subnets. A single-subnet node auto-homes every bind and HIDES the gap entirely — so
# this int SKIPS unless the node actually holds >=2 subnets (the real trigger; here: SPT_DEV gaining
# BIGNET as a second subnet).
#
# THE GAP. On a multi-subnet node a NEW-endpoint bind must be told its home:
#   spt api bind <id> --set-session-id <sid>                 -> HOME_REFUSED (which subnet?)
#   spt api bind <id> --set-session-id <sid> --subnet <name> -> BOUND
# The spt-HOSTED bringup cannot supply it: `spt endpoint run` has NO --subnet flag, and the broker
# injects $SPT_ENDPOINT_ID but NO home-subnet, so the plugin SessionStart `bind)` branch fires
# `api bind "$SPT_ENDPOINT_ID" --set-session-id "$sid"` (no --subnet) -> HOME_REFUSED -> the hook's
# `|| true` swallows it -> zero perch -> the server's ENDPOINT_RUN_ONLINE_TIMEOUT (~25s, no perch).
# Pinned HOME_REFUSED on 0.11.0 / 0.12.0 / 0.12.1 / 0.13.1 / 0.13.2 (this is policy, not a code bug).
#
# doyle's fix (ADRs 0026/0027, v0.13.3+): the broker injects $SPT_ENDPOINT_SUBNET and `api bind` gains
# an env-fallback for the home subnet, so the SHIPPED hooks stay UNCHANGED. When that lands, Case 2's
# HOME_REFUSED expectation flips (an env-homed bind succeeds) and Case 1's endpoint-run binds a perch.
# Until then this script GREEN = the gap reproduces exactly as reported. See docs/SPT-CORE-FINDINGS.md
# (F-017). The adapter manifest/hooks are CORRECT as-is; the fix is spt-core-side.
#
# Cases 2 & 3 are fast (a bare bind probe, no harness spawn) and run on any multi-subnet node.
# Case 1 is the E2E manifestation: it spawns a REAL claude into a broker PTY (the daemon also hosts a
# Psyche) and asserts NO perch ever binds. It is heavy + flaky-prone, so it is gated behind
# SPTC_ACCEPTANCE=1. All disposable, per-run-unique ids (REQ-HAZARD-PERCH-COLLISION — NEVER a live
# agent's id); everything torn down on exit. Idempotent.
# Run: sh ci/subnet/multi-subnet-bringup-int.sh                 (cases 2+3)
#      SPTC_ACCEPTANCE=1 sh ci/subnet/multi-subnet-bringup-int.sh  (+ case 1 E2E)   exit 0 = pass.
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
A=claude-spt
OWLERY="${LOCALAPPDATA:-$HOME/AppData/Local}/spt-core/owlery"

command -v spt >/dev/null 2>&1 || { echo "SKIP: no spt on PATH"; exit 0; }

# Multi-subnet GATE — the gap is invisible on a single-subnet node (every bind auto-homes).
SUBNETS=$(spt endpoint list 2>/dev/null | grep -E '^SUBNET ' | awk '{print $2}')
NSUB=$(printf '%s\n' "$SUBNETS" | grep -c .)
if [ "${NSUB:-0}" -lt 2 ]; then
  echo "SKIP: node holds ${NSUB:-0} subnet(s); F-017 only reproduces on a multi-subnet node (>=2)"; exit 0
fi
HOME_SUB=$(printf '%s\n' "$SUBNETS" | head -1)
echo "multi-subnet node: [$(printf '%s' "$SUBNETS" | tr '\n' ' ')] — home for control case = $HOME_SUB"

RUN=$$
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

# Disposable perch ids this run created (purged on exit).
MADE=""
RUNPID=""
cleanup() {
  for id in $MADE; do spt endpoint purge "$id" --yes >/dev/null 2>&1 || true; done
  # Case 1 broker-spawned claude (by run pid, subtree) + its disposable Psyche (cmdline carries the id).
  [ -n "$RUNPID" ] && taskkill //PID "$RUNPID" //T //F >/dev/null 2>&1
  if [ -n "${C1_ID:-}" ]; then
    for p in $(wmic process where "name='claude-spt-psyche.exe' and commandline like '%$C1_ID%'" get processid 2>/dev/null | tr -dc '0-9 \n' | tr ' ' '\n' | grep -E '^[0-9]+$'); do
      taskkill //PID "$p" //T //F >/dev/null 2>&1
    done
    spt endpoint shutdown "$C1_ID" >/dev/null 2>&1 || true
    spt endpoint purge "$C1_ID" --yes >/dev/null 2>&1 || true
    rm -rf "$OWLERY/$C1_ID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

# ── Case 2 — the core gap: a NEW-endpoint bind WITHOUT --subnet is HOME_REFUSED ──────────────
C2_ID=f017-norhome-$RUN
out=$(spt api bind "$C2_ID" --set-session-id "sess-$RUN" 2>&1)
case "$out" in
  HOME_REFUSED:*) ok "Case 2: bind w/o --subnet -> HOME_REFUSED ([$out])" ;;
  BOUND:*)        MADE="$MADE $C2_ID"; bad "Case 2: bind w/o --subnet BOUND unexpectedly — F-017 fixed? (env-home landed?) [$out]" ;;
  *)              bad "Case 2: unexpected bind result: [$out]" ;;
esac

# ── Case 3 — control: the SAME bind WITH --subnet succeeds (BOUND) ────────────────────────────
C3_ID=f017-withhome-$RUN
out=$(spt api bind "$C3_ID" --set-session-id "sess-$RUN" --subnet "$HOME_SUB" 2>&1)
case "$out" in
  BOUND:*) MADE="$MADE $C3_ID"; ok "Case 3: bind WITH --subnet $HOME_SUB -> BOUND ([$out])" ;;
  *)       bad "Case 3: bind WITH --subnet did not BIND: [$out]" ;;
esac

# ── Case 1 (E2E, gated) — spt-hosted `endpoint run` (no --subnet flag) yields NO perch ────────
if [ "${SPTC_ACCEPTANCE:-0}" = "1" ]; then
  if spt adapter list 2>/dev/null | grep -q "$A"; then
    C1_ID=f017-run-$RUN
    runout=$(spt endpoint run --adapter "$A" --id "$C1_ID" --start 2>&1)
    RUNPID=$(printf '%s' "$runout" | grep -oE 'pid=Some\([0-9]+\)' | grep -oE '[0-9]+' | head -1)
    # Poll ~36s: the gap = SessionStart's no-subnet bind HOME_REFUSEs (|| true), so a perch NEVER binds.
    i=0; while [ "$i" -lt 18 ]; do [ -f "$OWLERY/$C1_ID/info.json" ] && break; sleep 2; i=$((i+1)); done
    if [ -f "$OWLERY/$C1_ID/info.json" ]; then
      bad "Case 1: endpoint run BOUND a perch — F-017 fixed (broker now injects \$SPT_ENDPOINT_SUBNET?)"
    else
      ok "Case 1: endpoint run (no --subnet) bound NO perch after ~36s — ONLINE_TIMEOUT gap reproduced"
    fi
  else
    echo "Case 1: SKIP (claude-spt not registered)"
  fi
else
  echo "Case 1: SKIP (set SPTC_ACCEPTANCE=1 — spawns a real claude + Psyche, mutates perch state)"
fi

[ "$fail" -eq 0 ] && { echo "MULTI-SUBNET-BRINGUP-INT OK (F-017 gap reproduces)"; exit 0; } || { echo "MULTI-SUBNET-BRINGUP-INT FAIL"; exit 1; }
