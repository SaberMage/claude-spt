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
     - **End-user (plugin only):** the `.spt` carries native binaries, so it ships **per-OS** —
       pick the host's. Detect: `os=$(uname -s)` → MINGW*/MSYS*/CYGWIN*=windows, Linux=linux,
       Darwin=macos; `arch=$(uname -m)` → x86_64/amd64=x86_64, arm64/aarch64=aarch64. Then
       `spt adapter add --release SaberMage/spt-claude-code --asset adapter-$os-$arch.spt` — fetches
       the per-OS `adapter-<os>-<arch>.spt` asset (tar root = `manifest.toml` + `strings/` + native
       tool binaries), extracts to the durable home, registers. `--tag <ver>` pins a version. v1
       ships windows + linux. Recommended (from the monorepo, no dedicated repo); needs the spt
       release carrying `--release`.

3. **Verify activation.** Re-run `spt adapter list` — `claude-spt` must read **active**
   (no `deregistered`). The `[digest]`/`[session]` templates invoke `claude-spt-digest` +
   `claude-spt-psyche` by **bare name**, and spt-core resolves them **from the adapter install dir**
   (the `from …/adapters/_github/<safe>/` path in `spt adapter list`), where `--release` activation
   already extracted them beside the manifest. **No PATH copy needed** (REQ-INSTALL-11, spt v0.8.0
   Feature B; verified live on v0.8.1 — digest + daemon-hosted Psyche both resolve from the install
   dir). If either ever fails to start, confirm both `.exe`s are present in that install dir — their
   absence is a packaging defect, not a PATH problem. *(Legacy F-006 interim PATH-copy: retired.)*

4. **ccs wiring (optional — SCOPE setup #7).** Detect `~/.ccs`:
   - Present → ccs is installed. The shipped `claude-spt:ccs` profile leaf-replaces the session
     command with `ccs` (drop-in for `claude`) → run live/ready agents on ccs backends
     (glm/kimi/custom) via `--adapter claude-spt:ccs` (e.g. `/sptc:live`, `/sptc:ready`,
     `spt endpoint run --adapter claude-spt:ccs`). Check `command -v ccs`; if `~/.ccs` exists but `ccs`
     isn't on PATH, point the user at their ccs bin dir. No action needed if unwanted (base
     `claude-spt` is unaffected).
   - Absent → ccs is an optional CLI router for driving alternate model backends (glm/kimi/custom) in
     place of `claude`. To enable: install ccs (its docs), then re-run `/sptc:setup`. Skip if unwanted.

5. **Subnet onboarding (optional — SCOPE setup #3/#4).** A subnet is the private group of paired
   machines that makes `/sptc:send`, `/sptc:ready`, and live agents work cross-machine (local use
   needs none). Check: `spt subnet status`.
   - In a subnet → to invite a machine: `spt subnet show-code` (6-digit code + URI + QR); on the
     joiner: `spt subnet join <name> --code <code>`.
   - Not in one → offer create (`spt subnet create <name>` — seed-holder; prints code/URI/QR) or join
     (`spt subnet join <name> --code <code>`). Skip if single-machine.
   - Full verb guidance → **/sptc:subnet**. **Elevation:** create/join/show-code are
     OS-elevation-gated — Windows: elevated (UAC) shell; Linux desktop: pkexec/polkit or sudo
     terminal; Linux TTY: inline sudo; headless: print the command for the user to run elevated.

Idempotent and safe to re-run — the same bootstrap + activation the SessionStart hook performs.
