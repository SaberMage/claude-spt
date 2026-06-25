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
**release asset** on this monorepo, acquired with **`spt adapter add --release SaberMage/claude-spt`**
(doyle's `--release` source; needs **spt v0.7.3+ / counter 15** — not in 0.7.2). No dedicated
adapter repo: the asset is packed straight from `adapter/`.

Since v0.6.1 the asset is **ONE multi-platform fat `adapter.spt`** (ADR-0024 W1, spt-core ≥ 0.13.2):
a single archive bundles every supported platform's binaries, and install auto-resolves the host's.
This RETIRED the F-014 per-OS stopgap — there is no longer a default-vs-per-OS-asset split.

- **Pack:** `sh ci/publish/package-adapter.sh` (DRY-RUN) → `--apply` writes the single
  `dist/adapter.spt`. It validates the manifest, refuses a `min_spt_core_version < 0.13.2` (a fat
  archive needs it), requires **both** platforms' built tool binaries, and tars the archive **ROOT** =
  `manifest.toml` (renamed from `claude-spt.toml` — `adapter add` is root-only + exact-name) +
  `strings/` **shared at root**, plus each recognized target-triple's binaries under a `<triple>/` dir.
  Never uploads (operator's step).
<!-- [doc->REQ-DIST-ADAPTER-PEROS] -->
- **Fat layout (REQ-DIST-ADAPTER-PEROS).** Recognized triples = **`x86_64-pc-windows-msvc`** (win
  `.exe`) + **`x86_64-unknown-linux-gnu`** (linux ELF) — the ONLY two spt-core classifies in a fat
  archive. On install it places the shared root + **flattens this node's `<triple>/*` into the install
  dir**, so the bare-name command tokens (`claude-spt`, `cc-spt-idle-translate`) still resolve at `<install_dir>/`
  (REQ-INSTALL-11). **Footgun:** an unrecognized top-level dir is silently treated as a shared-root
  entry and lands flat — the packer guards this (refuses any stray top-level dir); for a platform
  beyond the two triples, ship a *separate* single-triple asset via `--asset`, never a third dir here.
- **Build both platforms first** (the packer needs both binary sets present):
  - **Windows (native):** `sh ci/digest/build.sh && sh ci/idle-translate/build.sh` →
    `tools/*/target/release/*.exe`. (`ci/digest/build.sh` builds the consolidated `claude-spt` crate
    — digest/psyche/post-update; `ci/psyche/build.sh` is a shim that defers to it — ADR-0006/U2.)
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
    cargo zigbuild --release --target x86_64-unknown-linux-gnu --manifest-path tools/claude-spt/Cargo.toml
    cargo zigbuild --release --target x86_64-unknown-linux-gnu --manifest-path tools/cc-spt-idle-translate/Cargo.toml
    ```
    → `tools/*/target/x86_64-unknown-linux-gnu/release/*` carrying real `ELF x86-64 GNU/Linux`
    binaries (verified). Then `sh ci/publish/package-adapter.sh --apply` packs BOTH into one
    `dist/adapter.spt`.
- **Publish:** attach the single `dist/adapter.spt` to the GitHub release on `SaberMage/claude-spt`.
  End users `spt adapter add --release SaberMage/claude-spt` (default asset `adapter.spt`, or
  `--tag <ver>` to pin) — the fat archive auto-resolves the host's binaries, no `--asset` needed. The
  `[update] avenue = "gh_release"` self-update fetches the same default `adapter.spt`, host-agnostic.
  - **F-015 note (Windows):** a binary-changing update still can't overwrite a binary a running live
    agent locks — but spt-core ≥ 0.13.2's W3 fix runs the live psyche from a `<perch>/.live-bin`
    own-copy, so the install-dir binary stays lock-free (validated 2026-06-22). Strings/hook-only
    releases always land fine.
  - **Local dogfood before upload (recommended):** extract `dist/adapter.spt`, flatten this node's
    triple into a dir (`cp <triple>/* .`), then `spt adapter {translate,digest}-proof claude-spt --dir
    <dir> --manifest <dir>/manifest.toml` — proves the flattened binaries resolve + run without any
    upload or registry mutation.
  - **`/sptc:setup` coupling.** The fat default is host-agnostic, so setup needs no os-detection /
    `--asset` — a bare `adapter add --release` suffices. (The current setup body still detects os/arch
    + passes `--asset`; harmless, simplifying it to the bare default is a follow-on.)
- **Binaries (install-dir resolution — REQ-INSTALL-11).** A `--release`/`--github` acquisition extracts
  the `.spt` archive's `manifest.toml` + `strings/` **+ both tool binaries** into the adapter install
  dir (`…/adapters/_github/<safe>/`). The command templates use **bare names** (`claude-spt`,
  `cc-spt-idle-translate`), which spt-core resolves **from that install dir** (v0.8.0 Feature B /
  REQ-INSTALL-11) — **no PATH placement needed** (dogfood-proven on v0.8.1 for both binaries; F-006
  RESOLVED, interim retired). The pack therefore MUST carry both binaries (the resolution source). Note:
  a plain local-dev `spt adapter add <manifest.toml>` copies manifest + strings only (no binaries in the
  install dir), so local-dev runtime still relies on the built binary being on PATH (e.g. the CI ints
  prepend `target/release`); the install-dir path is the end-user `--release` story.
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
