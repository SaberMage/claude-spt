<!-- Install UX — every command real and copy-paste-correct per OS (DOCS-STRATEGY #1/#3).
     Repo slug SaberMage/claude-spt (renamed from spt-claude-code, U3). [doc->REQ-DIST-INSTALL-UX] -->
# claude-spt

SpT's official adapter for Claude Code. Run your own named "live agents" to gain agent-to-agent messaging, durable context lifecycles, and more.

This Claude Code plugin is built atop `spt-core` for its resource interop and lifecycle management layers. SpT helps devs pave a path for their preferred LLM(s) + harness(es) to interact with and remember a variety of tools and role-bound agents. Its construction draws only from `spt-core`'s public surfaces: [`SaberMage/spt-releases`](https://github.com/SaberMage/spt-releases) + [its official docs](https://sabermage.github.io/spt-releases). Hence it serves to be the exemplary harness adapter for future adapters to follow.

For Claude Code, this adapter installs an `sptc` plugin. All skills reside under the `/sptc:*` namespace.

## Install

### Method A: Terminal installation

Claude Code must already be installed. Pick your shell:

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

**bash (macOS / Linux / Git Bash on Windows)**

```bash
command -v spt >/dev/null 2>&1 || curl -fsSL https://sabermage.github.io/spt-releases/install.sh | sh
spt adapter add --release SaberMage/claude-spt
```

To get `spt` to pick up as a command in your terminal after the install script, open a fresh shell.

### Method B: Copy-paste agent prompt

Hand this to a coding agent (Claude Code, etc.) to install everything in one go:

```text
Install claude-spt from SaberMage on GitHub.
```

**Agents start here:**
> Ensure Claude Code is installed as it is a prerequisite. Then, run this in one bash call, in order:
> `spt adapter list` line for `claude-spt`:
>
> ```bash
> command -v spt >/dev/null 2>&1 || curl -fsSL https://sabermage.github.io/spt-releases/install.sh | sh
> spt adapter add --release SaberMage/claude-spt
> spt adapter list | grep claude-spt
> ```
> Report the outcome to your operator. Advise them to create their first live agent by opening a fresh terminal and entering the `spt` command.

## Usage

After installation, get started by opening a fresh terminal. Run the `spt` command to create your first endpoint - a home for your live agent.

SpT is great for a single agent who builds a long-running project... The SpT magic *really* begins when you have more than one endpoint (live agent) operating on either one node (device), or multiple nodes in an SpT subnet (mesh network). Learn more here: https://github.com/SaberMage/spt-releases. I highly recommend pointing your agent to these repositories and asking it to explain whatever you want to understand!

## Updating

One lever keeps the adapter current — symmetric with install:

```bash
spt adapter update claude-spt
```

After a version update, spt-core prints the next step. Run **`/reload-plugins`** in Claude Code to pick up refreshed skills/hooks.

## Deeper docs (warning: outdated)

- [Quickstart](docs-site/src/quickstart.md) — install → bring-up → reachable, under ten minutes.
- [Harness contract](docs-site/src/reference/harness-contract.md) — how Claude Code hook events map onto `spt`.
- [`SCOPE.md`](SCOPE.md) · [`CONTEXT.md`](CONTEXT.md) · [`docs/adr/`](docs/adr/) — decisions and the domain model.

The `claude-spt` project is an intentional dogfeeding of the `spt-core` developer ecosystem and experience. While building this project, capabilities found to be defunct or missing from `spt-core`'s docs or API are used to improve the public-facing `spt-core` dev experience.
