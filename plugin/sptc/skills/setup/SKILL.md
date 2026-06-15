---
name: setup
description: |
  Install or repair spt-core for this Claude Code session (mid-session installer).
allowed-tools: [Bash]
---

# /sptc:setup

> **Self-contained by necessity.** Unlike other `/sptc:*` skills, `setup` cannot rely on
> UPS-injection of its body: it runs precisely when spt-core may be **absent**, so
> `spt adapter get-string` (the injection source) is unavailable. The operative steps therefore live
> in this SKILL.md (the floor); the file-backed `[strings.skills].setup` body mirrors them for the
> spt-present repair path. See `docs/adr/0001-distribution-splits-by-volatility.md`.

Covers the mid-session install gap (ADR-0001): a user who installs the plugin mid-session has not had
a SessionStart bootstrap fire, so `/sptc:setup` runs the same invisible-installer bootstrap to fetch +
verify spt-core on demand.

**Do this:**

1. If spt-core is already present (`command -v spt && spt --version`), report the version and stop.
2. Otherwise run the published install-on-demand bootstrap (spt-releases
   `harness-contract/install-on-demand.md`):
   - **POSIX:** `curl -fsSL https://sabermage.github.io/spt-releases/install.sh | sh`
   - **Windows (PowerShell):** `irm https://sabermage.github.io/spt-releases/install.ps1 | iex`
3. `PATH` is not reloaded in this shell after a fresh install — verify with the absolute path:
   `"$HOME/.local/bin/spt" --version`. After this, `spt update` handles signed self-updates.
