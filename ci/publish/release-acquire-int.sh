#!/bin/sh
# Integration proof for the END-USER adapter acquisition leg: `spt adapter add --release
# <user/repo>` fetches the `adapter.spt` GitHub release asset (packed by package-adapter.sh),
# extracts it, and leaves claude-spt ACTIVE sourced from the per-adapter `_github/<safe>` install
# dir — distribution straight from the monorepo, no dedicated repo. Encodes the dogfood-proven
# acquire as deterministic CLI assertions on a real spt-core (>= v0.7.3, where `--release` lands).
# The LLM is never in the loop. [int->REQ-DIST-ADAPTER-RELEASE]
#
# Mutates the node-local adapter registry AND hits the network (GitHub release download), so it is
# gated behind SPTC_ACCEPTANCE=1, spt>=0.7.3, and GitHub reachability — it SKIPs (rc 0) otherwise so
# offline/old-spt hosts stay green. Idempotent: removes what it adds. Run:
#   SPTC_ACCEPTANCE=1 sh ci/publish/release-acquire-int.sh   (exit 0 = pass).
# Override target with SPTC_RELEASE_REPO / SPTC_RELEASE_TAG.
set -u
REPO="${SPTC_RELEASE_REPO:-SaberMage/spt-claude-code}"
TAG="${SPTC_RELEASE_TAG:-v0.1.0}"

if [ "${SPTC_ACCEPTANCE:-0}" != "1" ]; then echo "SKIP: set SPTC_ACCEPTANCE=1 to run (mutates registry + downloads from GitHub)"; exit 0; fi
command -v spt >/dev/null 2>&1 || { echo "SKIP: no spt on PATH"; exit 0; }
ver=$(spt --version 2>/dev/null | awk '{print $NF}')
case "$ver" in
  0.7.2|0.7.1|0.7.0|0.6.*|0.5.*|0.4.*|0.3.*|0.2.*|0.1.*|0.0.*)
    echo "SKIP: spt $ver < 0.7.3 (\`adapter add --release\` lands in v0.7.3 / counter-15)"; exit 0 ;;
esac
# Network preflight — SKIP (not FAIL) on an offline host so the slow lane stays green there.
if command -v curl >/dev/null 2>&1; then
  curl -sfI "https://github.com/$REPO/releases" >/dev/null 2>&1 || { echo "SKIP: github.com/$REPO unreachable (offline)"; exit 0; }
else
  echo "SKIP: no curl for the reachability preflight"; exit 0
fi

fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
# Leave no registration behind however we exit.
trap 'spt adapter remove claude-spt >/dev/null 2>&1 || true' EXIT INT TERM

# 0. Clean start — drop any prior claude-spt registration so the acquire is the thing under test.
spt adapter remove claude-spt >/dev/null 2>&1

# 1. ACQUIRE from the GitHub release — the end-user one-liner.
out=$(spt adapter add --release "$REPO" --tag "$TAG" 2>&1)
case "$out" in
  *registered*|*active*|*fetched*) ok "acquire: adapter add --release $REPO@$TAG succeeded" ;;
  *) bad "adapter add --release failed: $out" ;;
esac

# 2. Verify ACTIVE and sourced from the per-adapter _github install dir (NOT the local monorepo).
list=$(spt adapter list 2>&1)
line=$(printf '%s\n' "$list" | grep '^claude-spt:')
case "$line" in *active*) ok "verified: claude-spt active after --release acquire" ;; *) bad "claude-spt not active: $line" ;; esac
case "$line" in *_github*) ok "sourced from the _github install dir (real --release extract)" ;; *) bad "not sourced from _github: $line" ;; esac
# safe-name of the repo (user/repo -> user-repo) appears in the install path.
safe=$(printf '%s' "$REPO" | tr '/' '-')
case "$line" in *"$safe"*) ok "install dir carries the repo safe-name ($safe)" ;; *) bad "repo safe-name '$safe' not in source path: $line" ;; esac

# 3. Profiles/strings shipped inside the .spt resolve through the registry (the asset was complete).
case "$list" in *claude-spt:ccs*) ok "shipped profile resolves from the .spt: claude-spt:ccs" ;; *) bad "ccs profile not resolved from --release asset" ;; esac
lbl=$(spt adapter get-string claude-spt adapter_label 2>&1)
[ "$lbl" = "Claude Code (spt)" ] && ok "file-backed strings shipped in the .spt resolve: adapter_label" || bad "adapter_label='$lbl'"

[ "$fail" -eq 0 ] && { echo "RELEASE-ACQUIRE-INT OK"; exit 0; } || { echo "RELEASE-ACQUIRE-INT FAIL"; exit 1; }
