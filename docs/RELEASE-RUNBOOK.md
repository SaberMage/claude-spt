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
