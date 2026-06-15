# /sptc:setup — operative instructions

> Delivered file-backed via the `claude-spt` adapter `[strings]`
> (`[strings.skills].setup = { file = "skills/setup.md" }`), resolved at injection time. The cplugs
> SKILL.md stays a thin skeleton (ADR-0001).

**Goal:** install or repair spt-core for this session — the mid-session installer that covers the
gap when no SessionStart bootstrap has fired (a user who installs the plugin mid-session).

**Do this:**

1. Check whether spt-core is already present: `command -v spt && spt --version`. If it reports a
   version, spt-core is installed — nothing to do; report the version and stop.
2. Otherwise run the published install-on-demand bootstrap (verbatim against the spt-releases
   contract, `harness-contract/install-on-demand.md`):
   - **POSIX:** `curl -fsSL https://sabermage.github.io/spt-releases/install.sh | sh`
   - **Windows (PowerShell):** `irm https://sabermage.github.io/spt-releases/install.ps1 | iex`
3. `PATH` is not reloaded in the current shell after a fresh install — verify with the absolute
   path for the first call: `"$HOME/.local/bin/spt" --version` (POSIX). Report the version.
4. After this initial bootstrap, `spt update` handles signed self-updates automatically — the user
   does not run setup again.

This is the same bootstrap the SessionStart hook runs; it is idempotent and safe to re-run.
