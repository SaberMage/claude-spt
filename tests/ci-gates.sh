#!/bin/sh
# Unit tests for CI helpers (pure/deterministic; no real bus or push needed).
# Run: sh tests/ci-gates.sh   (exit 0 = pass).
. "$(dirname "$0")/../ci/lib/spt-bus.sh"
fail=0

# resolve_spt_send: explicit override wins. Use a REAL executable (sh) — MSYS does not honour
# `chmod +x` on an arbitrary temp file as `-x`, so synthesise nothing. [unit->REQ-CI-OWL-DISCOVERY]
realexe=$(command -v sh)
got=$(SPTC_CI_BUS="$realexe" resolve_spt_send)
[ "$got" = "$realexe" ] && echo "ok   override resolves" || { echo "FAIL override: got [$got]"; fail=1; }

# resolve_spt_send: a non-executable override is ignored (no false positive).
bad=$(mktemp)  # plain file, not executable
got=$(SPTC_CI_BUS="$bad" resolve_spt_send 2>/dev/null)
[ "$got" != "$bad" ] && echo "ok   non-exec override rejected" || { echo "FAIL non-exec accepted"; fail=1; }
rm -f "$bad"

# run-gates.sh: valid shell + carries the load-bearing gates. [unit->REQ-CI-GATES]
g="$(dirname "$0")/../ci/run-gates.sh"
sh -n "$g" && echo "ok   run-gates syntax" || { echo "FAIL run-gates syntax"; fail=1; }
grep -q 'traceable-reqs check' "$g" && echo "ok   gate: traceable-reqs" || { echo "FAIL missing traceable gate"; fail=1; }
grep -q 'sh -n' "$g" && echo "ok   gate: shell-syntax" || { echo "FAIL missing syntax gate"; fail=1; }

[ "$fail" -eq 0 ] && { echo "CI-HELPERS OK"; exit 0; } || { echo "CI-HELPERS FAIL"; exit 1; }
