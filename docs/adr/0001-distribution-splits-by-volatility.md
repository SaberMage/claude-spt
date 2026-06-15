<!-- [doc->REQ-DIST-PLUGIN-SKELETON] -->
<!-- [doc->REQ-DIST-HOOKS-API] -->
<!-- [doc->REQ-DIST-BOOTSTRAP-INSTALL] -->
<!-- [doc->REQ-UPS-INJECTION] -->
# Distribution splits by volatility: a thin skeleton plugin, an spt-conducted manifest + binary

## Status

accepted (2026-06-14)

## Context

`spt-claude-code` is the `claude-spt` adapter — simultaneously spt-core's v1 acceptance proof,
its first casual-end-user entrypoint (a Claude Code plugin on `SaberMage/cplugs`), and an
invisible spt-core installer. It must ship as a CC plugin, yet almost all real logic now lives
inside the `spt` binary and the CC adapter manifest, both **conducted by spt-core**, not by the
plugin author.

Forces:

1. **Two very different churn rates.** Skill *instructions*, the `[digest]` extractor, profiles,
   strings, and hints change often. The plugin's *structure* (which skills exist, hook wiring,
   bootstrap) changes rarely. Coupling them to one release cadence means either over-bumping the
   marketplace or letting logic rot.
2. **Claude Code has no plugin-file integrity check.** In-place edits to an installed plugin do
   not orphan it; only *old version directories* orphan on a version bump (GC'd after 7 days).
   So low-churn structure is safe to ship via the marketplace, and high-churn logic does *not*
   need to ride the marketplace at all.
3. **The skill `/spt:` namespace must be preserved** (legacy parity). User-scope skills under
   `~/.claude/skills` cannot namespace (they surface as bare `/live`, collision-prone), so skills
   must stay **plugin-provided**.
4. **Users install mid-session**, so the plugin cannot assume a SessionStart fire has installed
   spt-core; the bootstrap and a `/spt:setup` skill must cover the gap.

## Decision

Split the adapter across **three layers by volatility** (see `SCOPE.md` §"Distribution
architecture"):

| Layer | Contents | Home | Churn |
|---|---|---|---|
| **Skeleton plugin** | namespaced `/spt:*` skill *skeletons*, `hooks.json`, SessionStart bootstrap, `plugin.json` | `SaberMage/cplugs` | low |
| **spt binary** | all logic | spt-core domain (signed, peer-propagated) | high |
| **CC adapter manifest** | `[digest]` extractor, profiles, strings, hints | spt-core adapter registry (**not** plugin files) | medium |

Concretely:

- **The marketplace plugin is a true thin skeleton.** It carries skill *skeletons* (frontmatter
  + a stub body), `hooks.json`, a SessionStart bootstrap, and `plugin.json` — **no binary, no
  manifest, no embedded logic.** [`REQ-DIST-PLUGIN-SKELETON`]
- **`hooks.json` delegates to `spt api`** rather than carrying adapter behavior. The hook commands
  invoke the spt binary's published `api` surface; the plugin ships no binary of its own (contrast
  legacy, which shipped `owl.exe` and called it directly). [`REQ-DIST-HOOKS-API`]
- **A SessionStart bootstrap installs spt-core when absent** — the invisible-installer pattern.
  A user who installs the plugin gets spt-core for free. [`REQ-DIST-BOOTSTRAP-INSTALL`]
- **Skill instructions are delivered by UPS-injection.** A `UserPromptSubmit` hook detects `/spt:X`
  in the prompt and injects X's real instructions as `additionalContext`, sourced from the adapter
  `[strings]` (file-backed, so the manifest doesn't bloat). SKILL.md files stay skeletons; the
  volatile instruction text lives in spt-core-conducted strings. [`REQ-UPS-INJECTION`]
- **The "bulk" install/update is manifest + binary**, conducted by spt-core's own framework (the
  file-pull channel), not a marketplace bump. The marketplace plugin rarely needs a version bump
  and never orphans an active install.

### Rejected alternatives

- **Global user-scope skills** (`~/.claude/skills`) — lose the `/spt:` namespace (bare `/live`,
  collision-prone). Rejected.
- **fetch-stub skills** (SKILL.md fetches its real body at runtime) — VETOED by the operator:
  adds terminal noise, latency, and an extra tool call per invocation. UPS-injection chosen
  instead. (`SCOPE.md` §"Skill-instruction delivery".)
- **A fat plugin shipping the binary** (legacy `owl.exe` model) — couples high-churn logic to the
  marketplace cadence and forces the binary/handoff/cache-prune machinery the thin skeleton has no
  need for. Rejected; logic rides the spt binary + adapter registry.

### Open / to-confirm

- **UPS-fires-on-slash-command is an empirical assumption.** The design assumes
  `UserPromptSubmit` fires when the prompt is a `/spt:X` slash-command. This is undocumented and
  must be confirmed at build time; if it does **not** fire, the fallback is in-SKILL.md
  instructions. (Tracked under `REQ-UPS-INJECTION`; see `SKELETON-PLAN.md`.)
- **File-backed `[strings]` is an M12 spt-core dependency** — until M12 publishes, instruction
  bodies cannot be externalized; skeleton SKILL.md files may carry interim inline instructions.

## Consequences

<!-- [doc->REQ-DIST-MANIFEST-SCHEMA] -->
- The marketplace plugin can sit static across many manifest/binary updates → the
  version-of-truth is the spt-core-tracked manifest/binary version (`spt adapter list` /
  `/spt:version`), **not** the marketplace `plugin.json` version. The CC adapter manifest
  (`adapter/claude-spt.toml`) is authored against spt-core's **published** `manifest.schema.json`
  (vendored at `adapter/manifest.schema.json`) and CI-gated against it (`ci/manifest/`). These are distinct numbers on
  independent schedules (see `docs/RELEASE-RUNBOOK.md`).
- New obligation: a dual update path kept in sync — file-pull (real) + a cautionary
  `claude plugin update` (skeleton sync only).
<!-- [doc->REQ-DIST-SHORTCUT-BASENAME] -->
- Forces the cplugs **plugin-name** question, now **ruled (operator, 2026-06-14)**: because CC
  invokes skills as `/<plugin>:<skill>` (the skill prefix is hard-tied to the `plugin.json` name —
  no override; confirmed against the official plugin docs), the marketplace plugin is named
  **`sptc`** and skills surface as **`/sptc:*`** for now. **Succession plan:** once `spt-claude-code`
  proves parity, flip `plugin.json` name `sptc`→`spt` (skills become `/spt:*`) and retire/rename
  legacy owl's cplugs `spt` plugin in the same coordinated move (two plugins cannot share the
  `spt` name). `sptc` is the single-substitution seam — the flip is `s/sptc/spt/`.
- Mints no new REQs beyond those already seeded for the skeleton milestone; this ADR is the
  `doc`-stage evidence for `REQ-DIST-PLUGIN-SKELETON`, `REQ-DIST-HOOKS-API`,
  `REQ-DIST-BOOTSTRAP-INSTALL`, and `REQ-UPS-INJECTION`.
