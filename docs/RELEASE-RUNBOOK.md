# Release runbook

> How an spt-claude-code release ships. The spine is fixed (changelog · bump · regenerate
> docs · tag · publish · docs publish). **Release here is LIGHT: signing is DELEGATED to the
> `spt` binary — there is NO two-key signing ceremony in this project.** spt-claude-code is a
> thin adapter; the heavy signed-release machinery lives in spt-core, not here.

<!-- [<doc>->REQ-EXAMPLE-REL] (illustration; escaped per docs/TRACEABILITY.md) -->

## Publish targets

An spt-claude-code release lands in **two places**, by volatility:

1. **The `SaberMage/cplugs` marketplace** — the thin **skeleton plugin** (namespaced
   `/spt:*` skill skeletons, `hooks.json`, the SessionStart bootstrap, `plugin.json`). This
   is low-churn: it only changes on **structural** plugin changes, not on logic/instruction
   updates.
2. **The spt-core adapter registry** — the volatile bulk: the CC adapter **manifest**
   (`[digest]` extractor, profiles, strings, hints) **+ binary**. This publish is
   **spt-core-conducted** (the same framework that conducts adapter updates), not a plugin
   file push.

## One-time setup

No signing-key ceremony in this project. **Signing is delegated to the `spt` binary**, which
handles adapter manifest/binary integrity through spt-core's own signed-update framework. Keep
no release keys here. The only setup is marketplace/registry publish credentials for the two
targets above (a `cplugs` push token + whatever the spt-core adapter-registry publish step
requires).

## Per release

1. **Bump** the version (the plugin `plugin.json` version and/or the adapter manifest version —
   note these are distinct numbers; see Notes) if needed; **regenerate generated docs**
   (the mdBook `docs-site/` build + `llms.txt` / schema / CLI-help exports); land everything
   green.
2. **Write the user-facing changelog** — add a `## [<version>] - <date>` section at the top of
   `CHANGELOG.md` with **Added / Changed / Fixed** subsections. This section becomes the public
   release body verbatim, so it is the changelog every user reads. Rules:
   - **User-facing UX only.** What a person using the product notices or does differently. Name
     the actual commands / flags / surfaces they touch (`/spt:*` skills, `cc`, `/spt:setup`).
   - **No internal lingo** — no requirement ids, internal module names, commit hashes, or
     milestone / hazard codes. A reader who has never seen the source must understand every line.
   - **Flag breaking changes** prominently under Changed.
   - The release **fails loudly** if the tagged version has no `## [<version>]` section — the
     changelog is not optional.
3. **Tag**: `git tag <vX.Y.Z> && git push origin <vX.Y.Z>`. This triggers:
   - the **docs-publish workflow** — build `docs-site/` and publish to GitHub Pages (drift-gated;
     see `docs/DOCS-STRATEGY.md`).
4. **Publish** (light — signing delegated to `spt`):
   - **Skeleton plugin** → push to the `SaberMage/cplugs` marketplace **only when the plugin
     skeleton structurally changed** (new/removed skill skeleton, hook wiring, bootstrap, or
     `plugin.json`). Most releases do not bump the marketplace.
   - **Manifest + binary** → publish through the **spt-core adapter registry**; the `spt`
     binary performs signing/integrity as part of spt-core's adapter-update framework. You do
     **not** run a separate signing step.

## cplugs skeleton publish — concrete mechanics

<!-- [doc->REQ-DIST-PLUGIN-SKELETON] -->
The concrete cplugs marketplace steps, captured from the sister project's
`claude_skill_owl/docs/DEPLOY.md`. **Take only the SKELETON SUBSET.** spt-claude-code's cplugs
target is the **thin skeleton** — `/spt:*` skill skeletons, `hooks.json`, the SessionStart
bootstrap, `plugin.json`. **No binary, no manifest in cplugs** — the binary + adapter manifest
ride the **spt-core adapter registry** (spt-conducted; the *other* publish target above), so
none of owl's binary-lifecycle machinery applies here.

> **Now scripted (`ci/publish/`).** The validate + stage mechanics below are codified:
> `ci/publish/validate-skeleton.sh` is a binary installability gate (valid `plugin.json` with
> `name=sptc`; valid `hooks.json` whose referenced wrappers all exist; every skill has a
> `SKILL.md`; **no runtime-state / binary / manifest leak in the published surface**) — it runs in
> `ci/run-gates.sh` (the `skeleton-validate` gate) and is unit-tested by `tests/skeleton-validate.sh`.
> `ci/publish/package-skeleton.sh` codifies the per-bump copy below — validates first, **dry-run by
> default**, stages only the skeleton subset, never pushes (the marketplace commit/push stays the
> operator's step).

**One-time marketplace setup:**

```bash
# Clone the marketplace repo
git clone https://github.com/SaberMage/cplugs.git ~/.claude/plugins/marketplaces/cplugs
# Register a "cplugs" entry in ~/.claude/plugins/known_marketplaces.json
#   source: { source: "github", repo: "SaberMage/cplugs" }
```

**Per skeleton bump** (only when the skeleton *structurally* changes — see "Per release"):

```bash
# 1. Bump plugin.json version. The plugin manager compares this to the cached copy and
#    SKIPS the update entirely if they match — a stale version = a silent no-update.
# 2. Copy skeleton files (NO binary) into the marketplace clone:
MARKET=~/.claude/plugins/marketplaces/cplugs/plugins/sptc
cp -r skills/*  "$MARKET/skills/"
cp -r hooks/*   "$MARKET/hooks/"
cp .claude-plugin/plugin.json "$MARKET/.claude-plugin/"
# 3. Commit + push the cplugs repo:
cd ~/.claude/plugins/marketplaces/cplugs && git add plugins/sptc/ \
  && git commit -m "sptc: <change>" && git push
```

**Pointer flip** (the authoritative install-state update):

```bash
claude plugin install sptc@cplugs   # un-orphans + rewrites installed_plugins.json atomically
# then, inside Claude Code:
/reload-plugins
```

**Gotchas (these DO apply to the skeleton):**
- **Never hand-patch `installed_plugins.json`** (`jq`/`sed` are brittle; CC may silently reject).
  Use the `claude plugin install` CLI — it's the atomic pointer flip + orphan-marker cleanup.
- **No legacy manual-install dir alongside the marketplace install.** A `~/.claude/plugins/<name>/`
  regular dir coexisting with the marketplace cache install makes `/plugin` report the plugin
  **not installed** (CC enumerates both; the untracked one wins the conflict). Keep the two exclusive.
- **Restart the Claude Code session after install** so the SessionStart hook re-runs and repopulates
  the plugin's env (`$OWL`/`$LIVE` equivalents) in Bash subprocesses.

**Explicitly NOT ours** (owl ships a live self-migrating binary; the thin skeleton has none, so
skip all of it): `owl.exe` binary sync · the cache targeted-prune + keep-PREVIOUS-version logic ·
the seamless binary handoff (owl Phase 18.4/18.5) · `DEPLOY.ps1`'s build/handoff orchestration.

> **RULED (operator, 2026-06-14) — cplugs plugin name = `sptc`.** CC ties the skill prefix to the
> `plugin.json` name (no override), so skills surface as `/sptc:*`. **Succession:** once parity is
> proven, flip `plugin.json` name `sptc`→`spt` (skills → `/spt:*`) and retire/rename legacy owl's
> cplugs `spt` plugin in the same coordinated move — two plugins cannot share the `spt` name. The
> flip is a single substitution `s/sptc/spt/` (plugin dir, `plugin.json` name, marketplace path).

## adapter manifest publish — the `adapter.spt` release asset

<!-- [doc->REQ-DIST-ADAPTER-RELEASE] -->
The CC adapter manifest (publish target #2) ships to end users as an **`adapter.spt`** GitHub
**release asset** on this monorepo, acquired with **`spt adapter add --release SaberMage/spt-claude-code`**
(doyle's `--release` source; needs **spt v0.7.3+ / counter 15** — not in 0.7.2). No dedicated
adapter repo: the asset is packed straight from `adapter/`.

- **Pack:** `sh ci/publish/package-adapter.sh` (DRY-RUN) → `--apply` writes
  `dist/adapter-<os>-<arch>.spt`. It validates the manifest, requires the built tool binaries (`sh
  ci/digest/build.sh && sh ci/psyche/build.sh`), and tars the archive **ROOT** = `manifest.toml`
  (renamed from `claude-spt.toml` — `adapter add` is root-only + exact-name), `strings/`, and the two
  binaries. Never uploads (operator's step).
- **Publish:** attach every per-OS `adapter-<os>-<arch>.spt` to the SAME GitHub release on
  `SaberMage/spt-claude-code`. End users `spt adapter add --release SaberMage/spt-claude-code --asset
  adapter-<os>-<arch>.spt` (or `--tag <ver>` to pin). `/sptc:setup` derives the host's os/arch and
  passes the matching `--asset` automatically.
<!-- [doc->REQ-DIST-ADAPTER-PEROS] -->
- **Per-OS (REQ-DIST-ADAPTER-PEROS) — the asset carries native binaries, so it is platform-specific.**
  v1 ships **windows + linux**. spt's `--release` takes a caller-named `--asset` (default
  `adapter.spt`) — it does NOT auto-pick per-OS, so we name + select. Naming: `adapter-<os>-<arch>.spt`
  (os ∈ windows|linux|macos, arch ∈ x86_64|aarch64), host-derived from `uname`, overridable with
  `SPTC_OS` / `SPTC_ARCH` (+ `SPTC_TARGET` = the cargo target triple for a cross build). Per-OS publish:
  - **Windows (native):** `sh ci/digest/build.sh && sh ci/psyche/build.sh && sh
    ci/publish/package-adapter.sh --apply` → `dist/adapter-windows-x86_64.spt`.
  - **Linux on a Linux host/runner (native):** the identical commands (the build scripts are portable
    — cargo, no `.exe`) → `dist/adapter-linux-x86_64.spt`.
  - **Linux cross-built FROM Windows (proven 2026-06-16):** bare `cargo build --target
    x86_64-unknown-linux-gnu` fails (`error: linker 'cc' not found` — the crate compiles, only the
    link needs a Linux linker), so use **`cargo-zigbuild`** (zig supplies the cross-linker):
    ```sh
    # one-time: install zig (a self-contained binary) + cargo-zigbuild
    cargo install cargo-zigbuild
    # download zig (e.g. 0.14.1) to a dir OUTSIDE the repo (do NOT keep it under tools/ — it's a
    # traceable-reqs scan root and zig's bundled libc C-headers trip the scanner), put zig.exe on PATH:
    #   e.g. ~/.sptc-zig/zig-x86_64-windows-0.14.1/zig.exe  →  export PATH="$HOME/.sptc-zig/...:$PATH"
    rustup target add x86_64-unknown-linux-gnu
    # cross-build both tool crates with zig as the linker
    cargo zigbuild --release --target x86_64-unknown-linux-gnu --manifest-path tools/claude-spt-digest/Cargo.toml
    cargo zigbuild --release --target x86_64-unknown-linux-gnu --manifest-path tools/claude-spt-psyche/Cargo.toml
    # pack the linux asset (SPTC_TARGET points the packer at target/<triple>/release)
    SPTC_OS=linux SPTC_ARCH=x86_64 SPTC_TARGET=x86_64-unknown-linux-gnu sh ci/publish/package-adapter.sh --apply
    ```
    → `dist/adapter-linux-x86_64.spt` carrying real `ELF x86-64 GNU/Linux` binaries (verified).
  - Attach BOTH assets to the one release.
  - **Coupling (do not skew):** the os-detecting `/sptc:setup` floor (cplugs skeleton + adapter
    strings) requests `--asset adapter-<os>-<arch>.spt`, so it must ship **with** a release that
    carries those per-OS assets — never before. Sequence: cut the per-OS-asset release FIRST, then
    republish the cplugs skeleton (next `plugin.json` bump) that points at it. A skeleton bump ahead
    of the assets would 404 end-user setup.
- **Binaries (copy-mode caveat):** registration copies `manifest.toml` + `strings/` only — **not**
  the binaries. The command templates use **bare names** (`claude-spt-digest`, `claude-spt-psyche`)
  ⇒ resolved from **PATH** (the `/sptc:setup` interim copies them onto PATH) until **v0.8.0 Feature B
  / REQ-INSTALL-11** resolves them from the adapter install dir (F-006). The archive carries them so
  the installer/Feature-B has a source.
- **Acquisition only:** `--release` does **not** establish an `[update]` self-update route (our
  manifest declares no `[update]` → COPY-mode registration). Re-acquire a newer version by re-running
  `--release --tag <newer>`. The signed `file_pull` self-update channel is a separate, later concern.

## Update path (dual, kept in sync)

Users receive updates two ways, and both must stay consistent:
- **File-pull (the real channel)** — spt-core conducts manifest + binary updates seamlessly;
  this is how logic and instruction churn reaches users. Version-of-truth = the
  manifest/binary version spt-core tracks (`spt adapter list` / `/spt:version`).
- **`claude plugin update` (cautionary, skeleton sync)** — only resyncs the low-churn
  marketplace skeleton on the rare structural bump. It is NOT the version-of-truth.

## Notes

- **Distinct numbers — never conflate them:** the **plugin (marketplace) version** (in
  `plugin.json`, bumps rarely) and the **adapter manifest/binary version** (spt-core-tracked,
  the user-visible version-of-truth). They move on independent schedules — the plugin can sit
  static across many manifest updates.
- **Trust model:** adapter manifest/binary integrity is the `spt` binary's responsibility via
  spt-core's signed-update framework — spt-claude-code defines no separate trust ceremony.
  (Claude Code has no plugin-file integrity check, which is why the skeleton plugin is safe to
  in-place-edit; only old version dirs orphan on update and are GC'd after 7 days.)
