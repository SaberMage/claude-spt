#!/bin/sh
# Install the sptc CI git hooks into .git/hooks (git does not auto-source repo hooks).
# Idempotent. [impl->REQ-CI-TRIGGER]
root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not a git repo"; exit 1; }
src="$root/ci/git-hooks/pre-push"
dst="$root/.git/hooks/pre-push"
[ -f "$src" ] || { echo "missing $src"; exit 1; }
cp "$src" "$dst" && chmod +x "$dst" && echo "installed: $dst"
echo "set SPTC_CI_RUNNER=<fleet-runner-agent-id> to enable the push ping (else gates run manually)."
