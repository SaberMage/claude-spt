#!/bin/sh
# Integration proof for the spt-hosted cc-launcher BRINGUP-BIND path — the gap that hid the operator's
# wall-b zero-perch (F-013). Drives the operator's EXACT flow against a real spt-core:
#
#   spt endpoint run --adapter claude-spt --id <disp> --start
#       -> broker spawns [session.self] (`claude`) into a held PTY + injects [env.SPT_ENDPOINT_ID]={id}
#       -> CC's SessionStart hook reads a POPULATED $SPT_ENDPOINT_ID -> sptc_register_verb=`bind`
#       -> `spt api bind <id>` self-registers a BOUND perch on disk
#   spt send <disp>  ->  reaches it (SENT = live PTY inject, REQ-SEND-SPT-HOSTED; QUEUED also accepted)
#
# This is the int that WOULD HAVE CAUGHT the bug: pre-v0.11.0, `endpoint run` did NOT substitute
# [env.<VAR>].value="{id}" (injected EMPTY), so SessionStart fell to `seed`-by-PPID instead of `bind`
# -> ZERO perch -> `spt send` NO_PERCH. doyle's v0.11.0 REQ-HAZARD-ENV-SUBST fix populates it.
# [int->REQ-CC-LAUNCHER-BIND]
#
# Spawns a REAL claude (the [session.self] target) into a broker PTY + the daemon livehost spawns its
# Psyche (base manifest is live-capable) + mutates node-local perch state — ALL torn down on exit.
# Gated behind SPTC_ACCEPTANCE=1 and spt >=0.11.0 (older silently seeds-not-binds). Disposable, per-run
# unique id (REQ-HAZARD-PERCH-COLLISION — NEVER a live agent's id). Idempotent.
# Run: SPTC_ACCEPTANCE=1 sh ci/launcher/bind-int.sh   (exit 0 = pass).
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
A=claude-spt
OWLERY="${LOCALAPPDATA:-$HOME/AppData/Local}/spt-core/owlery"

if [ "${SPTC_ACCEPTANCE:-0}" != "1" ]; then echo "SKIP: set SPTC_ACCEPTANCE=1 to run (spawns a real claude + Psyche, mutates perch state)"; exit 0; fi
command -v spt >/dev/null 2>&1 || { echo "SKIP: no spt on PATH"; exit 0; }
ver=$(spt --version 2>/dev/null | awk '{print $NF}')
case "$ver" in
  0.0.*|0.1.*|0.2.*|0.3.*|0.4.*|0.5.*|0.6.*|0.7.*|0.8.*|0.9.*|0.10.*)
    echo "SKIP: spt $ver < 0.11.0 (endpoint-run [env].value substitution = REQ-HAZARD-ENV-SUBST/F-013, counter 24)"; exit 0 ;;
esac
spt adapter list 2>/dev/null | grep -q "claude-spt" || { echo "SKIP: claude-spt not registered (spt adapter add)"; exit 0; }

RUN=$$
ID=ccbind-int-$RUN
RUNPID=""
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

cleanup() {
  # 1. Kill the broker-spawned claude (the [session.self] target) by its run pid, subtree.
  [ -n "$RUNPID" ] && taskkill //PID "$RUNPID" //T //F >/dev/null 2>&1
  # 2. Kill the disposable Psyche ONLY (cmdline carries this run's unique id — never wall-a's).
  for p in $(wmic process where "name='claude-spt.exe' and commandline like '%$ID%'" get processid 2>/dev/null | tr -dc '0-9 \n' | tr ' ' '\n' | grep -E '^[0-9]+$'); do
    taskkill //PID "$p" //T //F >/dev/null 2>&1
  done
  # 3. Take the endpoint offline + erase its perch.
  spt endpoint shutdown "$ID" >/dev/null 2>&1 || true
  spt endpoint stop "$ID" >/dev/null 2>&1 || true
  tok=$(cat "$OWLERY/$ID/api.token" 2>/dev/null)
  [ -n "$tok" ] && spt api session-end "$ID" --erase --token "$tok" >/dev/null 2>&1 || true
  rm -rf "$OWLERY/$ID" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

# Bring up the spt-hosted endpoint (returns immediately; the PTY session keeps running).
runout=$(spt endpoint run --adapter "$A" --id "$ID" --start 2>&1)
echo "$runout" | grep -q "ENDPOINT_RUN_STARTED:$ID" && ok "endpoint run started ($ID)" || bad "endpoint run did not start: [$runout]"
RUNPID=$(printf '%s' "$runout" | grep -oE 'pid=Some\([0-9]+\)' | grep -oE '[0-9]+' | head -1)

# Wait (bounded ~50s) for SessionStart to BIND the perch (the bug = this never appearing).
i=0; while [ "$i" -lt 25 ]; do [ -f "$OWLERY/$ID/info.json" ] && break; sleep 2; i=$((i+1)); done

# 1. The spt-hosted SessionStart bind produced a BOUND perch on disk (info.json + api.token + ready).
if [ -f "$OWLERY/$ID/info.json" ] && [ -f "$OWLERY/$ID/api.token" ]; then
  ok "SessionStart BOUND a perch on disk (owlery/$ID — the F-013 zero-perch is fixed)"
else
  bad "no bound perch at owlery/$ID after ~50s (SessionStart seeded-not-bound? SPT_ENDPOINT_ID empty?)"
fi

# 2. The bound perch is registered/online in this node's local roster.
spt endpoint list --local 2>/dev/null | grep -q "$ID" && ok "endpoint registered in local roster" || bad "$ID not in endpoint list --local"

# 3. The bound spt-hosted endpoint is REACHABLE — `spt send` reaches it (SENT = live PTY inject per
#    REQ-SEND-SPT-HOSTED; QUEUED = spooled, still reachable). NO_PERCH would mean no perch behind it.
sendout=$(printf 'ccbind-int reachability probe' | spt send "$ID" --from "$ID" 2>&1)
case "$sendout" in
  SENT:*)   ok "send reached the spt-hosted endpoint LIVE (SENT — PTY inject)" ;;
  QUEUED:*) ok "send reached the spt-hosted endpoint (QUEUED — spooled, reachable)" ;;
  *)        bad "send did not reach $ID: [$sendout]" ;;
esac

[ "$fail" -eq 0 ] && { echo "CC-LAUNCHER-BIND-INT OK"; exit 0; } || { echo "CC-LAUNCHER-BIND-INT FAIL"; exit 1; }
