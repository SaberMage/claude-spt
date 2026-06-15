#!/bin/sh
# sptc SessionStart bootstrap (POSIX) — install spt-core on demand if absent.
# Verbatim against the published contract: spt-releases harness-contract/install-on-demand.md.
# The invisible-installer pattern: a user who installs the sptc plugin gets spt-core for free.
# [impl->REQ-DIST-BOOTSTRAP-INSTALL]
set -eu

if ! command -v spt >/dev/null 2>&1; then
  echo "spt-core not found - installing..." >&2
  curl -fsSL https://sabermage.github.io/spt-releases/install.sh | sh
  # PATH is not yet reloaded in this shell — use the absolute install path for the first call.
  SPT="$HOME/.local/bin/spt"
else
  SPT="spt"
fi

"$SPT" --version
# After this initial bootstrap, `spt update` handles signed self-updates automatically.
