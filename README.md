<!-- Install UX — every command real and copy-paste-correct per OS (DOCS-STRATEGY #1/#3).
     Repo slug SaberMage/claude-spt (renamed from spt-claude-code, U3). [doc->REQ-DIST-INSTALL-UX] -->
# claude-spt

The **Spacetime (`spt`) adapter for Claude Code** — agent-to-agent messaging, live agents, and an
invisible `spt-core` installer, delivered as a Claude Code plugin. Built against `spt-core`'s
**published public surface only** (`SaberMage/spt-releases` + the GitHub Pages docs).

Two names, by domain: **`claude-spt`** is the spt-core-facing identity (this repo, the adapter, the
tool binary); **`sptc`** is the Claude Code plugin you install (its skills are `/sptc:*`). See
[`docs/adr/0005-name-unification.md`](docs/adr/0005-name-unification.md).

## Install

### Recommended — the plugin (Claude Code does the rest)

From inside Claude Code:

```text
/plugin marketplace add SaberMage/cplugs
/plugin install sptc@cplugs
```

Restart the session. On first start the plugin **bootstraps `spt-core` for you** if it is absent,
then `/sptc:setup` activates the adapter. Nothing else to run. (See the
[Quickstart](docs-site/src/quickstart.md).)

### Manual — install `spt-core`, then activate the adapter

If `claude-spt` is your first exposure to `spt-core`, install the binary first (the published
`spt-releases` per-platform installer), then add the adapter straight from this repo's releases. Pick
your shell:

**bash (macOS / Linux / Git Bash on Windows)**

```bash
command -v spt >/dev/null 2>&1 || curl -fsSL https://sabermage.github.io/spt-releases/install.sh | sh
spt adapter add --release SaberMage/claude-spt
```

**PowerShell (Windows)**

```powershell
if (-not (Get-Command spt -ErrorAction SilentlyContinue)) { irm https://sabermage.github.io/spt-releases/install.ps1 | iex }
spt adapter add --release SaberMage/claude-spt
```

**cmd (Windows)**

```bat
where spt >nul 2>nul || powershell -NoProfile -Command "irm https://sabermage.github.io/spt-releases/install.ps1 | iex"
spt adapter add --release SaberMage/claude-spt
```

The `adapter add --release` pulls the single multi-platform `adapter.spt` (manifest + strings + the
host's tool binaries) — no per-OS asset to choose. If `spt` is not yet on `PATH` after the install
script, open a fresh shell (it lands at `~/.local/bin/spt` on macOS/Linux, or
`%LOCALAPPDATA%\spt-core\bin\spt.exe` on Windows).

### Copy-paste agent prompt

Hand this to a coding agent (Claude Code, etc.) to install everything in one go:

> Install the claude-spt adapter. Run this in one bash call, in order, and report the final
> `spt adapter list` line for `claude-spt`:
>
> ```bash
> command -v spt >/dev/null 2>&1 || curl -fsSL https://sabermage.github.io/spt-releases/install.sh | sh
> spt adapter add --release SaberMage/claude-spt
> spt adapter list | grep claude-spt
> ```

## Updating

One lever keeps the adapter current — symmetric with install:

```bash
spt adapter update claude-spt
```

On a real version apply spt-core prints the next step: run **`/reload-plugins`** in Claude Code (it
cannot reload a plugin from inside a running session) to pick up refreshed skills/hooks. That is the
only manual residual.

## Docs

- [Quickstart](docs-site/src/quickstart.md) — install → bring-up → reachable, under ten minutes.
- [Harness contract](docs-site/src/reference/harness-contract.md) — how Claude Code hook events map onto `spt`.
- [`SCOPE.md`](SCOPE.md) · [`CONTEXT.md`](CONTEXT.md) · [`docs/adr/`](docs/adr/) — decisions and the domain model.

Public-surface-only is the whole point of this project: if a capability is missing from `spt-core`'s
published surface, that is a finding to report — never a reason to reach into `spt-core` source.
