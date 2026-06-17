#!/bin/sh
# Integration proof for /sptc:live's LiveAgent bringup against a REAL spt-core (>= v0.7.3): the
# `claude-spt:live` profile's [session.psyche_init] makes spt spawn the Psyche, and the resident
# relay (`spt api listen <id>`, the production delivery pipe — run inside CC's Monitor tool, heir to
# legacy `$LIVE start <id>`) binds the live perch and streams inbound as the canonical <EVENT>
# envelope. We play Monitor's role: spawn `api listen` as a CHILD PROCESS (persistent, NOT --once —
# --once is the degenerate no-Monitor path) with `--manifest` (the manifest loads ONLY via --manifest;
# `--adapter <name>` is just a name → without it LiveHost is None and no Psyche spawns), capture its
# stdout/stderr, send a probe, and assert the bringup markers. The LLM is never judged. [int->REQ-SKILL-LIVE]
#
# Covers BOTH legs of REQ-SKILL-LIVE int: (1) PSYCHE-SPAWN — version-dependent marker (M11 restructure,
# doyle 2026-06-16): on <0.8.0 `api listen` spawns the Psyche IN-PROCESS (`PSYCHE_SPAWNED:{id}-psyche`
# off the listen child, startup.rs spawn_psyche pre once/loop split); on >=0.8.0 the DAEMON livehost
# hosts it by spawning claude-spt-psyche (resolved by bare name from the adapter install dir) — assert
# the RESIDENT runner process + nested `{id}-psyche` perch dir (FINALIZED on v0.8.1 + the adapter
# greedy-prompt fix, 2026-06-16; see the >=0.8.0 leg below). (2) RELAY — the resident listen pipe delivers the probe (BOUND/READY/<EVENT> off the child,
# unchanged across versions). The per-pulse runner command construction is additionally covered by
# claude-spt-psyche unit tests (ci/psyche/build.sh).
#
# PSYCHE-SPAWN binary resolution: the psyche_init command invokes `claude-spt-psyche` by bare name.
# On v0.8.0+ (Feature B / REQ-INSTALL-11) spt resolves it FROM the adapter install dir (proven: the
# binary registration-copies into adapters/_github/<safe>/, no PATH interim needed). On 0.7.3 it must
# be on PATH (the F-006 interim copy). The >=0.8.0 leg now ASSERTS a resident runner (was skip-with-note
# pre-v0.8.1); the <0.8.0 leg still SKIPs when the runner is unresolvable. The relay leg asserts always.
#
# Spawns a real claude-spt-psyche (which launches a headless claude) + mutates node-local perch state,
# all torn down on exit. Gated behind SPTC_ACCEPTANCE=1. Idempotent.
# Run: SPTC_ACCEPTANCE=1 sh ci/psyche/live-relay-int.sh   (exit 0 = pass).
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
A=claude-spt
MAN="$ROOT/adapter/claude-spt.toml"
# Disposable perch id — NEVER a live agent's id (REQ-HAZARD-PERCH-COLLISION). Override BOTH identity
# env vars; pin OWL_SESSION_ID for the auth-gated seed/send/listen surfaces. PER-RUN UNIQUE ($$ suffix):
# the daemon hosts a Psyche at most ONCE per session_id, so a FIXED id/session would not re-host on a
# rerun (the first run's hosted-session memory suppresses it) — each CI run must be a fresh session.
# Option A (PREP-4): [session.psyche_init] is in the BASE manifest — NO `:live` profile. The adapter
# is BASE claude-spt; the live `api listen` COMMAND (not a composite) is what stamps state=live_agent
# and actualizes the Psyche. We still pass an explicit `--adapter claude-spt --manifest <man>` here:
# CI has no real `claude` parent process, so spt-core's bare-by-pid host_binaries resolution cannot
# fire (the anchor is `sh`/`timeout`, not `claude`). The explicit override remains valid on 0.9.0 and
# loads the same base manifest the bare flow would resolve. The TRUE bare-flow (no --adapter, by-pid
# resolution under a real claude host) is covered by the live /sptc:live VERIFY, not this int.
RUN=$$
ID=sptc-ci-liverelay-$RUN
SID=sptc-ci-liverelay-$RUN-sess
export SPTC_CI_ID="$ID" SPT_AGENT_ID="$ID" OWL_SESSION_ID="$ID"

if [ "${SPTC_ACCEPTANCE:-0}" != "1" ]; then echo "SKIP: set SPTC_ACCEPTANCE=1 to run (spawns a Psyche + mutates perch state)"; exit 0; fi
command -v spt >/dev/null 2>&1 || { echo "SKIP: no spt on PATH"; exit 0; }
ver=$(spt --version 2>/dev/null | awk '{print $NF}')
case "$ver" in
  0.7.2|0.7.1|0.7.0|0.6.*|0.5.*|0.4.*|0.3.*|0.2.*|0.1.*|0.0.*) echo "SKIP: spt $ver < 0.7.3 (daemon live path / counter-15)"; exit 0 ;;
esac
[ -f "$MAN" ] || { echo "SKIP: no manifest at $MAN"; exit 0; }

# Anchor pid: spt probes WINDOWS pids — from git-bash `$$` is the MSYS pid and reads as a dead anchor
# (STALE_SEED/NO_SEED). Use the WINPID column from `ps` when present (git-bash col 4); elsewhere `$$`
# is already the real pid spt probes.
ANCHOR=$(ps -p $$ 2>/dev/null | awk 'NR==2{print $4}'); case "$ANCHOR" in ''|*[!0-9]*) ANCHOR=$$;; esac

# Can the psyche runner be resolved on THIS host? (PATH now, or manifest-dir on v0.8.0+ Feature B.)
psyche_resolvable() {
  command -v claude-spt-psyche >/dev/null 2>&1 && return 0
  case "$ver" in 0.7.*) return 1 ;; *) return 0 ;; esac  # Feature B (manifest-dir resolution) lands in v0.8.0; >=0.8.0 resolvable
}

LF=$(mktemp 2>/dev/null) || { echo "FATAL: mktemp"; exit 2; }
CHILD=""
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
skip(){ echo "skip $1"; }
cleanup() {
  # Kill the spawned Psyche subtree first (the runner + its headless claude), by marker pid then name.
  pp=$(grep -oE 'PSYCHE_SPAWNED:[^ ]+ pid=[0-9]+' "$LF" 2>/dev/null | grep -oE '[0-9]+' | tail -1)
  [ -n "$pp" ] && taskkill //PID "$pp" //T //F >/dev/null 2>&1
  for p in $(tasklist 2>/dev/null | grep -i claude-spt-psyche | awk '{print $2}'); do taskkill //PID "$p" //T //F >/dev/null 2>&1; done
  [ -n "$CHILD" ] && kill "$CHILD" >/dev/null 2>&1
  spt endpoint shutdown "$ID" >/dev/null 2>&1 || true
  spt endpoint stop "$ID" >/dev/null 2>&1 || true
  rm -f "$LF" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Seed the harness-hosted startup (anchored to the pid that will parent the listen child).
spt api --adapter "$A" --manifest "$MAN" seed --pid "$ANCHOR" --session-id "$SID" >/dev/null 2>&1

# Spawn the resident relay as a CHILD (Monitor surrogate). timeout bounds it so a hang can't wedge CI.
timeout 30 spt api --adapter "$A" --manifest "$MAN" listen --parent-pid "$ANCHOR" "$ID" > "$LF" 2>&1 &
CHILD=$!

# Wait (bounded) for the bringup to announce readiness.
i=0; while [ "$i" -lt 25 ]; do grep -q "READY:$ID" "$LF" 2>/dev/null && break; sleep 1; i=$((i+1)); done

# 1. The live listen path binds the perch.
grep -q "BOUND:$ID" "$LF" 2>/dev/null && ok "live perch bound" || bad "no BOUND:$ID; log=[$(cat "$LF")]"
# 2. The live listen path announces readiness (the relay heartbeat is up).
grep -q "READY:$ID" "$LF" 2>/dev/null && ok "live listen READY:$ID" || bad "no READY:$ID; log=[$(cat "$LF")]"
# 3. PSYCHE-SPAWN — the marker model differs by version (M11 restructure; doyle 2026-06-16):
case "$ver" in
  0.7.*)
    # <0.8.0: `api listen` spawns the Psyche IN-PROCESS → `PSYCHE_SPAWNED:{id}-psyche pid=` off the
    # listen child's stderr. The bare `claude-spt-psyche` resolves via the F-006 PATH interim here.
    if grep -q "PSYCHE_SPAWNED:$ID-psyche pid=" "$LF" 2>/dev/null; then
      ok "Psyche spawned in-process ($(grep -oE "PSYCHE_SPAWNED:$ID-psyche pid=[0-9]+" "$LF" | head -1))"
    elif grep -q "PSYCHE_SPAWN_FAIL:" "$LF" 2>/dev/null && ! psyche_resolvable; then
      skip "psyche-spawn: runner unresolvable on spt $ver without the F-006 PATH interim (Feature B/REQ-INSTALL-11 lands v0.8.0) — $(grep -oE 'PSYCHE_SPAWN_FAIL:[^]]*' "$LF" | head -1)"
    else
      bad "no PSYCHE_SPAWNED marker (manifest declares psyche_init? runner resolvable?); log=[$(cat "$LF")]"
    fi
    ;;
  *)
    # >=0.8.0: the in-process spawn is gone (M11 restructure) — `api listen` emits only BOUND/READY +
    # stamps the perch `status="online"` IFF the resolved manifest declares [session.psyche_init]
    # (startup.rs:283 live_capable guard); the DAEMON reconcile then hosts the Psyche off that online
    # status (the `{id}-psyche` perch comes online; `LIVEHOST_PSYCHE:{id}` on the daemon's stderr).
    # RESOLVED (v0.8.1 + adapter greedy-prompt fix, 2026-06-16): hosting succeeds iff the daemon
    # spawned claude-spt-psyche AND the runner stays RESIDENT. Two bugs were in the way: (1) spt-core
    # <0.8.1 livehost did not reconcile (no spawn at all); v0.8.1 fixed it. (2) spt-core substitutes
    # `{psyche_prompt}` into the psyche_init command STRING then whitespace-SPLITS, so the multi-word
    # prompt arrived as stray argv tokens — the runner's non-greedy --prompt rejected the 2nd word
    # ("unknown arg") and exited 2 instantly → the daemon recorded a phantom hosted perch (nested
    # info.json status=online, real-looking pid) with NO live process and NO psyche_host_error. The
    # runner now parses --prompt greedily (slurps trailing tokens). DETECTION: the nested {id}-psyche
    # perch does NOT surface in `endpoint list` (it lives under the parent in the owlery), so assert on
    # the RESIDENT runner process + the nested perch dir for THIS id. This is also the REQ-INSTALL-11
    # install-dir-resolution proof: the runner resolved by bare name FROM the adapter install dir.
    OWL="${SPT_HOME:-$HOME/AppData/Local/spt-core}/owlery/$ID/nested/$ID-psyche/info.json"
    resident() { tasklist 2>/dev/null | grep -qi "claude-spt-psyche"; }
    j=0; while [ "$j" -lt 20 ]; do resident && [ -f "$OWL" ] && break; sleep 1; j=$((j+1)); done
    procs=$(tasklist 2>/dev/null | grep -ci "claude-spt-psyche")
    nested=no; [ -f "$OWL" ] && nested=yes
    if resident && [ -f "$OWL" ]; then
      ok "Psyche daemon-hosted: claude-spt-psyche runner RESIDENT for $ID-psyche (v0.8.1 livehost + greedy-prompt fix; REQ-INSTALL-11 install-dir resolution proven)"
    else
      bad "psyche-spawn: no resident claude-spt-psyche for $ID (v0.8.1 host gap or prompt-split regression); nested=$nested procs=$procs"
    fi
    ;;
esac

# Deliver a probe with body specials; the resident relay streams it live to the child's stdout.
printf 'live relay probe <a> & "b"' | spt send "$ID" --from relay-probe >/dev/null 2>&1
i=0; while [ "$i" -lt 20 ]; do grep -q 'type="msg"' "$LF" 2>/dev/null && break; sleep 1; i=$((i+1)); done

# 4. RELAY: the probe arrives as the canonical <EVENT> envelope with correct body escaping.
expected='<EVENT type="msg" from="relay-probe">live relay probe &lt;a&gt; &amp; &quot;b&quot;</EVENT>'
grep -qF "$expected" "$LF" 2>/dev/null && ok "probe relayed through the live pipe as escaped <EVENT>" || bad "envelope mismatch; log=[$(cat "$LF")]"
# 5. The endpoint registered as a live_agent (the :live kind was honored on bringup).
kind=$(spt daemon status 2>&1 | sed -n '/local endpoints/,$p' | grep -E "(^| )$ID( |$)")
case "$kind" in *live_agent*) ok "endpoint registered as live_agent (:live kind honored)" ;; *) bad "endpoint not live_agent: [$kind]" ;; esac

[ "$fail" -eq 0 ] && { echo "LIVE-RELAY-INT OK"; exit 0; } || { echo "LIVE-RELAY-INT FAIL"; exit 1; }
