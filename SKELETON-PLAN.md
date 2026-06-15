# SKELETON milestone — JIT plan

> First body of work for `spt-claude-code`, on the **v0.6.0 (M10) public surface**. JIT: this
> plans the skeleton milestone only — M12-dependent pieces are explicitly out of scope until
> M12 publishes (doyle pings when its surface is live). Authoritative why/what: `SCOPE.md`.

## Goal

Stand up the **thin cplugs skeleton plugin** — the low-churn marketplace artifact — and the
traceability + release foundation around it. No spt-core logic lives here; the plugin is
skill skeletons + `hooks.json` (→ `spt api`) + a SessionStart bootstrap + `plugin.json`.

## Scope (v0.6.0-supported, startable now)

In:
- Traceability gate green + skeleton-milestone REQs seeded (DONE this body — see below).
- cplugs publish mechanics captured in `docs/RELEASE-RUNBOOK.md` (DONE this body).
- The plugin skeleton itself: `plugin.json`, `hooks.json` (delegating to `spt api`),
  SessionStart bootstrap that installs spt-core when absent, namespaced `/spt:*` skill
  skeletons for the KEEP set, `/spt:version`, the UPS-injection hook.
- ADR-0001 (distribution split: skeleton plugin vs spt-conducted manifest+binary).
- Empirical confirmation: does `UserPromptSubmit` fire on `/spt:X` slash-commands? (gates the
  UPS-injection design — REQ-UPS-INJECTION). Fallback = in-SKILL.md instructions if it doesn't.

Out (deferred to post-M12 — sequence after doyle's M12-live ping):
- File-backed `[strings]`, `adapter:profile` fallback, `[adapter] shortcut_basename`,
  `spt endpoint run` bringup picker, `spt rc` cross-node attach, `cc` launcher, `/spt:setup`,
  whoami→alias. (M12 public-surface deps — `SCOPE.md` §"spt-core upstream deps".)
- CI fleet wiring (own milestone) and docs-site mdBook build (own milestone) — both startable
  on v0.6.0 but not part of THIS skeleton body; planned next.

## Open design questions

- **cplugs plugin name** — legacy occupies `spt`; skeleton needs a distinct marketplace name
  (`spt-claude-code` / `claude-spt`?) while keeping the `/spt:` *skill* namespace. Resolve
  before any cplugs push. (`docs/RELEASE-RUNBOOK.md` OPEN note.)
- **UPS-on-slash-command** — design assumes UPS fires; confirm empirically (above).
- `/spt:setup` #9 verify fold-inline vs deferred (`SCOPE.md` §8 open item) — not skeleton-blocking.

## Tasks

- [x] Green `traceable-reqs check` (fix seed scan-root manifest_error + 4 template tag-leaks).
- [x] Seed skeleton-milestone REQs (inactive): DIST-PLUGIN-SKELETON, DIST-BOOTSTRAP-INSTALL,
      DIST-HOOKS-API, DIST-MANIFEST-SCHEMA, UPS-INJECTION, SKILL-VERSION.
- [x] Capture cplugs skeleton-publish mechanics in `docs/RELEASE-RUNBOOK.md`.
- [ ] Write ADR-0001 (distribution split) → `doc` evidence; activate reqs' `doc` stage.
- [ ] Scaffold `plugin/` (plugin.json), `hooks/` (hooks.json → `spt api`; UPS-injection hook),
      `skills/` (KEEP skeletons + `/spt:version`). Add these as `[scan].roots` when created.
- [ ] Empirically test UPS-fires-on-slash-command; record result in ADR / KNOWN-HAZARDS.
- [ ] Validate `plugin.json` + adapter manifest shape against published `manifest.schema.json`
      from `SaberMage/spt-releases`.
- [ ] Activate `impl`/`unit` stages + tag as each surface lands; `traceable-reqs check` EXIT=0.

## Gate

`traceable-reqs check` EXIT=0 with the skeleton milestone's reqs activated and covered, the
skeleton plugin installable from a local marketplace clone, and the manifest validating against
the published schema. Build/CI wiring is a separate milestone.
