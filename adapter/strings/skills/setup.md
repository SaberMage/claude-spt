# /sptc:setup — operative instructions

**Goal:** install or repair spt-core for this session **and activate the claude-spt adapter** — the
mid-session installer covering the gap when no SessionStart bootstrap has fired. Installing the
binary is only half the job: a present binary with a **deregistered** adapter has no
profiles/strings/hints/`[digest]`, so the `/sptc:*` surface is inert until activation.

<!-- [doc->REQ-SETUP-ACTIVATE] -->

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
     - **Local dev / dogfooding a repo checkout** (an `adapter/claude-spt.toml` near cwd):
       `spt adapter add ./adapter/claude-spt.toml`.
     - **End-user (plugin only):** `spt adapter add --release SaberMage/spt-claude-code` — fetches the
       single multi-platform `adapter.spt` (one archive bundling every supported platform's binaries
       beside a shared manifest; install auto-resolves the host's), extracts to the durable home,
       registers. No `--asset` / os-detection needed — the fat archive is host-agnostic (ADR-0024 W1).
       `--tag <ver>` pins a version. Needs spt **v0.13.2+** (the version that reads a fat archive).
       <!-- [doc->REQ-DIST-ADAPTER-PEROS] -->

3. **Verify + set active.** Re-run `spt adapter list` — `claude-spt` must read **active** (no
   `deregistered`). Then `spt adapter use claude-spt` so bare resolution lands here for the `claude`
   host (the legacy-parity bare flow — `/sptc:live`/`/sptc:ready` need no `--adapter`). The
   `claude-spt-digest` + `claude-spt-psyche` tools are invoked by bare name and resolve **from the
   adapter install dir** (the `from …` path in `spt adapter list`), where activation extracted them —
   no PATH copy needed. If either fails to start, confirm both are present in that dir (a packaging
   defect, not a PATH problem).

4. **ccs wiring (optional).** Detect `~/.ccs`:
   - Present → the shipped `claude-spt:ccs` profile leaf-replaces the session command with `ccs` (a
     drop-in for `claude`), so live/ready agents can run on ccs backends via `--adapter
     claude-spt:ccs`. Check `command -v ccs`; if `~/.ccs` exists but `ccs` isn't on PATH, point the
     user at their ccs bin dir.
   - Absent → ccs is an optional CLI router for alternate model backends in place of `claude`. To
     enable: install ccs, then re-run `/sptc:setup`. Skip if unwanted.
   <!-- [doc->REQ-SETUP-CCS] -->

5. **Subnet onboarding (optional).** A subnet is the private group of paired machines that makes
   `/sptc:send`, `/sptc:ready`, and live agents work cross-machine (local use needs none). Check
   `spt subnet status`:
   - In a subnet → invite a machine with `spt subnet show-code`; on the joiner, `spt subnet join`.
   - Not in one → offer **create** (`spt subnet create` — this node becomes seed-holder) or **join**
     (`spt subnet join`). Full verb guidance → **/sptc:subnet**.
   - **Elevation:** create/join/show-code are OS-elevation-gated — Windows: elevated (UAC) shell;
     Linux desktop: pkexec/polkit or sudo terminal; Linux TTY: inline sudo; headless: print the exact
     command for the user to run elevated.
   <!-- [doc->REQ-SETUP-SUBNET] -->

Idempotent and safe to re-run — the same bootstrap + activation the SessionStart hook performs.
