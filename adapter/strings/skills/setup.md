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
     - **End-user (plugin only, no repo checkout):** the `.spt` asset carries native binaries, so it
       ships **per-OS** — select the one matching this host. Detect os + arch:
       ```sh
       os=$(uname -s);  case "$os" in MINGW*|MSYS*|CYGWIN*|Windows*) os=windows;; Linux) os=linux;; Darwin) os=macos;; esac
       arch=$(uname -m); case "$arch" in x86_64|amd64) arch=x86_64;; arm64|aarch64) arch=aarch64;; esac
       ```
       then `spt adapter add --release SaberMage/spt-claude-code --asset adapter-$os-$arch.spt` —
       fetches the per-OS `adapter-<os>-<arch>.spt` release asset (a tar whose **root** holds
       `manifest.toml` + `strings/` + the native tool binaries) from the repo's GitHub release,
       extracts it to the durable adapter home, and registers it. Add `--tag <ver>` to pin a version
       (omit for latest). Re-running with a newer `--tag` is a manual re-acquire. `adapter add` is
       manifest-first (an invalid manifest registers nothing). (v1 ships **windows + linux** assets.
       Recommended path — straight from the monorepo, no dedicated repo. Needs the spt release that
       carries `--release`; the older `--github <root-manifest-repo>` is the alternative.)
       <!-- [doc->REQ-DIST-ADAPTER-PEROS] -->

3. **Verify activation.** Re-run `spt adapter list`: `claude-spt` must now appear **active** (no
   `deregistered`). Spot-check a profile resolves: `spt adapter get-string claude-spt:live adapter_label`
   (any shipped profile). Report the active state.

4. **Tool binaries on PATH (feature prerequisite + interim copy-mode fix).** The `[digest]` extractor
   (`claude-spt-digest`) and the Psyche runner (`claude-spt-psyche`) are invoked by **bare name** →
   resolved from PATH at runtime. Activation registers the manifest, but session-digest + LiveAgent
   Psyche only **function** once those two binaries resolve. Check: `command -v claude-spt-digest`
   and `command -v claude-spt-psyche`.
   - If both resolve → done.
   - If they MISS **after an `--release` activation**: the binaries shipped in the `adapter.spt` and
     extracted **beside the manifest** in the adapter's install dir, but `--release` copy-mode does
     not place them on PATH. **Interim fix:** find the extract dir (the `from …` path in
     `spt adapter list`, e.g. `…/adapters/_github/<safe>/`) and copy `claude-spt-digest` +
     `claude-spt-psyche` from there into a directory already on PATH (the spt bin dir — same dir as
     `spt` itself — works). Re-check `command -v`.
   - *(This interim step retires once spt-core resolves adapter binaries against the install dir
     before PATH — REQ-INSTALL-9, doyle. Until then, place them on PATH.)*

5. **ccs wiring (optional — SCOPE setup #7).** Detect `~/.ccs`:
   - **Present** → ccs is installed. The shipped **`claude-spt:ccs`** profile leaf-replaces the live
     session command with `ccs` (a drop-in for `claude`), so live/ready agents can run on ccs's
     configured backends (glm/kimi/custom from `~/.ccs/config.json`) instead of `claude`. Use it by
     selecting the `:ccs` composite: e.g. `/sptc:live` / `/sptc:ready` under `--adapter claude-spt:ccs`,
     or `spt endpoint run --adapter claude-spt:ccs`. Sanity-check `command -v ccs`; if `~/.ccs` exists
     but `ccs` is not on PATH, point the user at their ccs install's bin dir. (No action needed if
     they don't want ccs — base `claude-spt` is unaffected.)
   - **Absent** → ccs is an optional CLI router that lets your spt sessions drive alternate model
     backends (glm/kimi/custom) in place of `claude`. To enable: install ccs (see its docs), then
     re-run `/sptc:setup`. Skip if not wanted.

   <!-- [doc->REQ-SETUP-CCS] -->

After this initial bootstrap + activation, `spt update` handles signed self-updates automatically —
the user does not run setup again. The whole flow is idempotent and safe to re-run.
