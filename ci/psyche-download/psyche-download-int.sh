#!/bin/sh
# Integration proof for the spt-core v0.15.0 `spt api psyche-download <id>` resume-context verb
# (REQ-DIST-RESUME-CONTEXT, T3). This is the CORE-CONTRACT half of the int: pure spt-core CLI
# behavior, deterministic, self-hosted, NO real CC needed — a throwaway perch is bind-created via
# `api bind` (which writes the perch record + session id directly, no broker/CC spawn), the four
# contract behaviors are asserted against a live 0.15.0 binary, then the perch is purged.
#
# The SessionStart INJECTION E2E — the adapter's session-start.sh hook actually CONSUMING this pull
# and injecting it into a live CC — genuinely needs the NEW plugin installed + a real CC session, so
# it stays a LOGGED dogfood-after-plugin-land tier (CHECKPOINT-COMMUNE-PLAN.md §Deferred validations),
# NOT covered here (doyle's gate ruling, 2026-06-24). The int evidence tag sits on the assertion block
# below, not here.
#
# Needs spt >= 0.15.0 (the verb) + a subnet to home the throwaway perch. Feature-detects and SKIPs
# otherwise (never a hard fail on an older / subnet-less node). Idempotent. Run: exit 0 = pass.
#
# WATCH-ITEM (doyle, 2026-06-24): the POSITIVE assertion polls for the <pending-commune> across a
# retry window that must straddle the daemon's ~5s ingest pulse — too NARROW a window can miss a
# late-appearing pending slice on a loaded host (cf. the seedmap starvation flake). Widened to 8 polls
# here for headroom; widen further (not lower) if it ever flakes on a contended box — never treat a
# miss as a real contract failure.
set -u
ADAPTER=claude-spt
ID="sptc-pdint-$$"
SID="sptc-pdint-sess-$$"

command -v spt >/dev/null 2>&1 || { echo "SKIP: no spt on PATH"; exit 0; }

# Verb capability-detect (lands in spt v0.15.0).
if ! spt api psyche-download --help >/dev/null 2>&1; then
  echo "SKIP: spt 'api psyche-download' absent (needs v0.15.0). Hook wiring: tests/hooks-parse.sh green."
  exit 0
fi
echo "ok   verb present: api psyche-download <id> --session-id"

# A subnet to home the throwaway perch (bind refuses to guess when the node holds >1 subnet).
SUBNET=$(spt endpoint list 2>/dev/null | sed -n 's/^SUBNET \([^ ]*\).*/\1/p' | head -1)
[ -n "$SUBNET" ] || { echo "SKIP: no subnet on this node to home the test perch"; exit 0; }

cleanup() {
  printf 'y\n' | spt endpoint purge "$ID" --force --yes >/dev/null 2>&1 || true
  rm -f ".claude/$ID-commune.md"
}
trap cleanup EXIT INT TERM

# Bind-create the perch (NO CC — api bind writes the perch record + session id directly).
if ! spt api --adapter "$ADAPTER" bind "$ID" --set-session-id "$SID" --subnet "$SUBNET" >/dev/null 2>&1; then
  echo "SKIP: could not bind-create the test perch (subnet $SUBNET)"
  exit 0
fi

rc=0
errf="${TMPDIR:-/tmp}/sptc-pdint-$$.err"

# 1. NO-CONTEXT: a fresh perch -> exit 0, EMPTY stdout, NO-CONTEXT:<id> on stderr (the hook skips).
out=$(spt api --adapter "$ADAPTER" psyche-download "$ID" --session-id "$SID" 2>"$errf"); ec=$?
err=$(cat "$errf" 2>/dev/null)
if [ "$ec" -eq 0 ] && [ -z "$out" ] && { printf '%s' "$err" | grep -q "NO-CONTEXT:$ID"; }; then
  echo "ok   NO-CONTEXT: fresh perch -> exit 0, empty stdout, NO-CONTEXT on stderr"
else
  echo "FAIL NO-CONTEXT contract: exit=$ec stdout=[$out] stderr=[$err]"; rc=1
fi

# 2. AUTH: a wrong --session-id is rejected (non-zero exit; AUTH_REFUSED).
if spt api --adapter "$ADAPTER" psyche-download "$ID" --session-id "WRONG-$SID" >/dev/null 2>&1; then
  echo "FAIL AUTH: a wrong --session-id was NOT rejected"; rc=1
else
  echo "ok   AUTH: wrong --session-id rejected"
fi

# 3. POSITIVE: a not-yet-synthesized commune drop is returned VERBATIM as <pending-commune>. Retried
#    across the brief pre-synthesis window (the daemon eventually ingests + clears the drop). This is
#    the core resume-context behavior the SessionStart hook injects. [int->REQ-DIST-RESUME-CONTEXT]
MARK="PDINT-POS-$$"
mkdir -p .claude
printf '%s resume delta\n' "$MARK" > ".claude/$ID-commune.md"
got=""
i=0
while [ "$i" -lt 8 ]; do  # 8-poll window straddles the ~5s daemon ingest pulse (see WATCH-ITEM header)
  o=$(spt api --adapter "$ADAPTER" psyche-download "$ID" --session-id "$SID" 2>/dev/null)
  if printf '%s' "$o" | grep -q "$MARK"; then got="$o"; break; fi
  i=$((i + 1)); sleep 1
done
if { printf '%s' "$got" | grep -q '<pending-commune>'; } && { printf '%s' "$got" | grep -q "$MARK"; }; then
  echo "ok   POSITIVE: not-yet-synthesized commune returned VERBATIM as <pending-commune>"
else
  echo "FAIL POSITIVE: pending-commune not returned (got=[$got])"; rc=1
fi

rm -f "$errf"
[ "$rc" -eq 0 ] && { echo "PSYCHE-DOWNLOAD-INT OK"; exit 0; } || { echo "PSYCHE-DOWNLOAD-INT FAIL"; exit 1; }
