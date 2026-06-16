# /sptc:setup — operative instructions

> Delivered file-backed via the `claude-spt` adapter `[strings]`
> (`[strings.skills].setup = { file = "skills/setup.md" }`), resolved at injection time. The cplugs
> SKILL.md stays a thin skeleton (ADR-0001).

**Goal:** install or repair spt-core for this session **and ACTIVATE the claude-spt adapter** — the
mid-session installer that covers the gap when no SessionStart bootstrap has fired (a user who
installs the plugin mid-session). Installing the binary is only half the job: a present binary with
a **deregistered** adapter has no profiles/strings/hints/`[digest]`, so `/sptc:*` injection has
nothing to source. Setup must leave the adapter **active**.

<!-- [doc->REQ-SETUP-ACTIVATE] -->

**Do this:**

1. **Binary.** Check whether spt-core is present: `command -v spt && spt --version`.
   - If absent, run the published install-on-demand bootstrap (verbatim against the spt-releases
     contract, `harness-contract/install-on-demand.md`):
     - **POSIX:** `curl -fsSL https://sabermage.github.io/spt-releases/install.sh | sh`
     - **Windows (PowerShell):** `irm https://sabermage.github.io/spt-releases/install.ps1 | iex`
   - `PATH` is not reloaded in the current shell after a fresh install — verify with the absolute
     path for the first call: `"$HOME/.local/bin/spt" --version` (POSIX). Report the version.

2. **Adapter activation (the step a present binary still needs).** Run `spt adapter list` and look
   for `claude-spt`:
   - If `claude-spt` is listed and **not** marked `deregistered` → the adapter is **active**; report
     "adapter active" and go to step 4.
   - If `claude-spt` is **missing or `deregistered`** → **activate** it. Pick the source:
     - **Local dev / dogfooding from a repo checkout** (an `adapter/claude-spt.toml` is present near
       cwd): `spt adapter add ./adapter/claude-spt.toml` (the file-form takes any path + filename).
     - **End-user (plugin only, no repo checkout):**
       `spt adapter add --github SaberMage/claude-spt` — the dedicated adapter repo whose root holds
       `manifest.toml` + `strings/` + the tool binaries. `adapter add` is manifest-first (an invalid
       manifest registers nothing) and conducts the declared `[update]` avenue once.

3. **Verify activation.** Re-run `spt adapter list`: `claude-spt` must now appear **active** (no
   `deregistered`). Spot-check a profile resolves: `spt adapter get-string claude-spt:live adapter_label`
   (any shipped profile). Report the active state.

4. **Tools on PATH (feature prerequisite).** The `[digest]` extractor (`claude-spt-digest`) and the
   Psyche runner (`claude-spt-psyche`) are invoked by **bare name** → resolved from PATH at runtime.
   Activation registers the manifest, but session-digest + LiveAgent Psyche only **function** once
   those two binaries are on PATH (they ride the installer / the dedicated adapter repo). If either
   is missing from PATH, note it — registration succeeds but those features stay inert until they
   resolve.

After this initial bootstrap + activation, `spt update` handles signed self-updates automatically —
the user does not run setup again. The whole flow is idempotent and safe to re-run.
