---
name: setup
description: |
  Install or repair spt-core AND activate the claude-spt adapter for this Claude Code session
  (mid-session installer + post-install activation).
allowed-tools: [Bash]
---

# /sptc:setup

> **Self-contained by necessity.** Unlike other `/sptc:*` skills, `setup` cannot rely on
> UPS-injection of its body: it runs precisely when spt-core may be **absent**, so
> `spt adapter get-string` (the injection source) is unavailable. The operative steps therefore live
> in this SKILL.md (the floor); the file-backed `[strings.skills].setup` body mirrors them for the
> spt-present repair path. See `docs/adr/0001-distribution-splits-by-volatility.md`.

Covers the mid-session install + activation gap (ADR-0001): a user who installs the plugin mid-session
has not had a SessionStart bootstrap fire, so `/sptc:setup` runs the same invisible-installer
bootstrap to fetch + verify spt-core on demand **and then activates the claude-spt adapter**. A
present binary is not enough: an unregistered/`deregistered` adapter has no profiles/strings/hints/
`[digest]`, so the `/sptc:*` surface is inert until activation.

**Do this:**

1. **Binary.** If spt-core is absent (`command -v spt && spt --version` reports nothing), run the
   published install-on-demand bootstrap (spt-releases `harness-contract/install-on-demand.md`):
   - **POSIX:** `curl -fsSL https://sabermage.github.io/spt-releases/install.sh | sh`
   - **Windows (PowerShell):** `irm https://sabermage.github.io/spt-releases/install.ps1 | iex`

   `PATH` is not reloaded in this shell after a fresh install — verify with the absolute path:
   `"$HOME/.local/bin/spt" --version`. After this, `spt update` handles signed self-updates.

2. **Activate the adapter.** Run `spt adapter list` and find `claude-spt`:
   - Listed and **not** `deregistered` → already active; report it and skip to step 3.
   - Missing or `deregistered` → activate it:
     - **Local dev / dogfooding a repo checkout** (an `adapter/claude-spt.toml` is present near cwd):
       `spt adapter add ./adapter/claude-spt.toml` (the file-form accepts any path + filename).
     - **End-user (plugin only):** `spt adapter add --release SaberMage/spt-claude-code` — fetches
       the published `adapter.spt` release asset (tar root = `manifest.toml` + `strings/` + tool
       binaries) from the repo's GitHub release, extracts to the durable home, registers. `--tag
       <ver>` pins a version. Recommended (ships from the monorepo, no dedicated repo); needs the spt
       release carrying `--release`.

3. **Verify.** Re-run `spt adapter list` — `claude-spt` must read **active** (no `deregistered`).
   The `[digest]` extractor (`claude-spt-digest`) and Psyche runner (`claude-spt-psyche`) resolve by
   **bare name from PATH**; if either is missing, registration still succeeds but session-digest /
   LiveAgent Psyche stay inert until those binaries are on PATH. Note any that are missing.

Idempotent and safe to re-run — the same bootstrap + activation the SessionStart hook performs.
