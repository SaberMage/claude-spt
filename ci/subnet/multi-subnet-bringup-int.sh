#!/bin/sh
# Validation for F-017 — the multi-subnet bringup gap, FIXED in spt-core v0.14.0 (the
# endpoint-creation-flow milestone, REQ-RUN-MULTISUBNET-HOME / ADRs 0026-0027). This started life as
# the W6 regression SEED that pinned the gap on <= 0.13.2; on v0.14.0 the expected outcomes FLIP from
# "gap reproduces" to "fix confirmed". Still multi-subnet-gated (single-subnet auto-homes + never sees
# any of this). Validates spt-core's REQ-RUN-MULTISUBNET-HOME (their registry, not ours) — kept
# untagged here, like the original finding-repro seed.
#
# THE FIX (v0.14.0). `spt endpoint run` now HOMES an endpoint to one subnet at creation:
#   - multi-subnet node, no --subnet, non-interactive  -> REFUSES clear (MULTI_SUBNET_HOME + the subnet
#     list) INSTANTLY — replacing the old silent ~25s ENDPOINT_RUN_ONLINE_TIMEOUT (the F-017 gap).
#   - --subnet <name>                                  -> homes there; the harness binds (UNBOUND ->
#     ONLINE), no HOME_REFUSED.
# The underlying home-assignment POLICY is unchanged + still correct: a NEW-endpoint `api bind` without
# a home still HOME_REFUSEs (Case 2) — that policy is WHY `endpoint run` had to grow `--subnet`.
#
# Cases 1 & 2 are fast (a refuse + a bare bind probe, no harness spawn) and run on any multi-subnet
# node. Case 3 is the full E2E of the fix: it spawns a REAL claude into a broker PTY (the daemon also
# hosts a Psyche) and asserts the endpoint HOMES + BINDS (UNBOUND -> online) — gated behind
# SPTC_ACCEPTANCE=1. All disposable, per-run-unique ids (REQ-HAZARD-PERCH-COLLISION — NEVER a live
# agent's id); everything torn down on exit. Idempotent.
# Run: sh ci/subnet/multi-subnet-bringup-int.sh                      (cases 1+2)
#      SPTC_ACCEPTANCE=1 sh ci/subnet/multi-subnet-bringup-int.sh    (+ case 3 E2E)   exit 0 = pass.
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
A=claude-spt
OWLERY="${LOCALAPPDATA:-$HOME/AppData/Local}/spt-core/owlery"

command -v spt >/dev/null 2>&1 || { echo "SKIP: no spt on PATH"; exit 0; }

# v0.14.0 is the carrying release (endpoint run gained --subnet + the MULTI_SUBNET_HOME refuse).
if ! spt endpoint run --help 2>&1 | grep -q -- '--subnet'; then
  echo "SKIP: spt 'endpoint run' has no --subnet (needs v0.14.0 — the F-017 fix). On <= 0.13.2 the gap is unfixed."; exit 0
fi

# Multi-subnet GATE — the fix (and the gap it replaced) is invisible on a single-subnet node.
SUBNETS=$(spt endpoint list 2>/dev/null | grep -E '^SUBNET ' | awk '{print $2}')
NSUB=$(printf '%s\n' "$SUBNETS" | grep -c .)
if [ "${NSUB:-0}" -lt 2 ]; then
  echo "SKIP: node holds ${NSUB:-0} subnet(s); F-017 only manifests on a multi-subnet node (>=2)"; exit 0
fi
HOME_SUB=$(printf '%s\n' "$SUBNETS" | head -1)
echo "multi-subnet node: [$(printf '%s' "$SUBNETS" | tr '\n' ' ')] — home = $HOME_SUB"

RUN=$$
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

MADE=""
RUNPID=""
cleanup() {
  for id in $MADE; do spt endpoint purge "$id" --yes --force >/dev/null 2>&1 || true; done
  [ -n "$RUNPID" ] && taskkill //PID "$RUNPID" //T //F >/dev/null 2>&1
  if [ -n "${C3_ID:-}" ]; then
    for p in $(wmic process where "name='claude-spt.exe' and commandline like '%$C3_ID%'" get processid 2>/dev/null | tr -dc '0-9 \n' | tr ' ' '\n' | grep -E '^[0-9]+$'); do
      taskkill //PID "$p" //T //F >/dev/null 2>&1
    done
    spt endpoint shutdown "$C3_ID" >/dev/null 2>&1 || true
    spt endpoint stop "$C3_ID" >/dev/null 2>&1 || true
    spt endpoint purge "$C3_ID" --yes --force >/dev/null 2>&1 || true
    rm -rf "$OWLERY/$C3_ID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

# ── Case 1 — THE FIX: spt-hosted `endpoint run` without --subnet REFUSES clear + INSTANTLY ────
# (was the silent ~25s ENDPOINT_RUN_ONLINE_TIMEOUT). Non-interactive --start; expect no perch.
C1_ID=f017fix-run-$RUN
start=$(date +%s 2>/dev/null || echo 0)
out=$(spt endpoint run --adapter "$A" --id "$C1_ID" --start 2>&1)
end=$(date +%s 2>/dev/null || echo 0)
case "$out" in
  MULTI_SUBNET_HOME:*) ok "Case 1: endpoint run w/o --subnet -> MULTI_SUBNET_HOME refuse ([$out])" ;;
  *ENDPOINT_RUN_STARTED*|*ENDPOINT_RUN:*) MADE="$MADE $C1_ID"; bad "Case 1: endpoint run w/o --subnet STARTED a bringup — should refuse on a multi-subnet node [$out]" ;;
  *) bad "Case 1: unexpected endpoint-run result (expected MULTI_SUBNET_HOME): [$out]" ;;
esac
# The refuse must be IMMEDIATE — the gap it replaced was a ~25s hang. Allow generous slack (< 10s).
if [ "$start" -gt 0 ] && [ "$end" -gt 0 ]; then
  el=$((end - start))
  [ "$el" -lt 10 ] && ok "Case 1: refuse was immediate (${el}s, not the old ~25s timeout)" \
    || bad "Case 1: refuse took ${el}s — suspiciously close to the old ONLINE_TIMEOUT hang"
fi
[ -f "$OWLERY/$C1_ID/info.json" ] && { MADE="$MADE $C1_ID"; bad "Case 1: a perch was created despite the refuse"; } || ok "Case 1: no perch created (clean refuse, nothing to reap)"

# ── Case 2 — underlying POLICY (unchanged): a NEW-endpoint bind needs a home ──────────────────
C2_ID=f017fix-bind-$RUN
out=$(spt api bind "$C2_ID" --set-session-id "sess-$RUN" 2>&1)
case "$out" in
  HOME_REFUSED:*) ok "Case 2a: bind w/o --subnet -> HOME_REFUSED (home-assignment policy intact) ([$out])" ;;
  BOUND:*)        MADE="$MADE $C2_ID"; bad "Case 2a: bind w/o --subnet BOUND unexpectedly [$out]" ;;
  *)              bad "Case 2a: unexpected bind result: [$out]" ;;
esac
out=$(spt api bind "$C2_ID" --set-session-id "sess-$RUN" --subnet "$HOME_SUB" 2>&1)
case "$out" in
  BOUND:*) MADE="$MADE $C2_ID"; ok "Case 2b: bind WITH --subnet $HOME_SUB -> BOUND ([$out])" ;;
  *)       bad "Case 2b: bind WITH --subnet did not BIND: [$out]" ;;
esac

# ── Case 3 (E2E, gated) — `endpoint run --subnet` HOMES + the harness BINDS (UNBOUND -> online) ─
if [ "${SPTC_ACCEPTANCE:-0}" = "1" ]; then
  if spt adapter list 2>/dev/null | grep -q "$A"; then
    C3_ID=f017fix-home-$RUN
    runout=$(spt endpoint run --adapter "$A" --id "$C3_ID" --subnet "$HOME_SUB" --start 2>&1)
    case "$runout" in
      *ENDPOINT_RUN_STARTED*|*ENDPOINT_RUN:*) ok "Case 3: endpoint run --subnet $HOME_SUB STARTED ([$runout])" ;;
      *) bad "Case 3: endpoint run --subnet did not start: [$runout]" ;;
    esac
    RUNPID=$(printf '%s' "$runout" | grep -oE 'pid=[0-9]+' | grep -oE '[0-9]+' | head -1)
    # Poll ~40s for the harness to self-bind (UNBOUND -> bound/online). The gap = no perch ever bound.
    bound=0
    i=0; while [ "$i" -lt 20 ]; do
      row=$(spt endpoint list 2>/dev/null | grep "$C3_ID" | head -1)
      case "$row" in *alive=true*) bound=1; break ;; esac
      sleep 2; i=$((i+1))
    done
    [ "$bound" -eq 1 ] && ok "Case 3: harness HOMED $HOME_SUB + BOUND (UNBOUND -> online, no HOME_REFUSED)" \
      || bad "Case 3: endpoint never bound within ~40s (regressed to the no-perch gap?)"
  else
    echo "Case 3: SKIP (claude-spt not registered)"
  fi
else
  echo "Case 3: SKIP (set SPTC_ACCEPTANCE=1 — spawns a real claude + Psyche, mutates perch state)"
fi

[ "$fail" -eq 0 ] && { echo "MULTI-SUBNET-BRINGUP-INT OK (F-017 fix confirmed on v0.14.0)"; exit 0; } || { echo "MULTI-SUBNET-BRINGUP-INT FAIL"; exit 1; }
