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

- ~~cplugs plugin name~~ **RULED (operator, 2026-06-14): `sptc`** → skills `/sptc:*` (CC ties the
  prefix to `plugin.json` name, no override). Succession: flip `sptc`→`spt` on parity-proof,
  retiring legacy `spt` in the same move. `sptc` is the single-substitution rename seam.
- **UPS-on-slash-command** — design assumes UPS fires; confirm empirically (above).
- `/spt:setup` #9 verify fold-inline vs deferred (`SCOPE.md` §8 open item) — not skeleton-blocking.

## Tasks

- [x] Green `traceable-reqs check` (fix seed scan-root manifest_error + 4 template tag-leaks).
- [x] Seed skeleton-milestone REQs: DIST-PLUGIN-SKELETON, DIST-BOOTSTRAP-INSTALL, DIST-HOOKS-API,
      DIST-MANIFEST-SCHEMA, UPS-INJECTION, SKILL-VERSION.
- [x] Capture cplugs skeleton-publish mechanics in `docs/RELEASE-RUNBOOK.md`.
- [x] Write ADR-0001 (distribution split) → `doc` evidence (PLUGIN-SKELETON, HOOKS-API,
      BOOTSTRAP-INSTALL, UPS-INJECTION activated to `doc`).
- [x] `plugin/sptc/plugin.json` (name=sptc), `plugin/sptc/bootstrap.{sh,ps1}` (published
      install-on-demand verbatim; BOOTSTRAP-INSTALL → `doc,impl`), 9 skill skeletons (KEEP set +
      `/sptc:version`, thin stubs). Added `plugin` as a `[scan].root`.
- [x] Record spt-core public-surface finding **F-001** in `docs/SPT-CORE-FINDINGS.md`; reported.
- [ ] **BLOCKED on F-001 ruling:** the hook artifact. Held in BOTH media (CC `hooks.json` AND
      manifest `[hooks.*]`) pending gap-#2 (does the plugin hand-write `hooks.json`, or does
      spt-core materialize it from the manifest?). The 4 published mappings are ready (below).
- [ ] **BLOCKED on F-001 #3:** UPS-injection impl (the additionalContext channel HOW).
- [ ] UPS-fires-on-`/sptc:X` empirical test — run in a **throwaway** session (never
      `/reload-plugins` on the live perch); trivial UPS echo hook; report the narrow fire/no-fire.
- [ ] `/sptc:version` operative body + adapter manifest → validate against published
      `manifest.schema.json` (`reference/schema.md`); activate MANIFEST-SCHEMA, SKILL-VERSION.
- [ ] Tag `impl`/`unit` + activate as each surface lands; `traceable-reqs check` EXIT=0.

## Published hook→`spt api` mappings (ready-to-wire once F-001 #2 rules the medium)

From the published harness-contract (`api.md` / `integration-checklist.md` / `manifest.md`):

| Claude Code hook | `spt api` invocation (published) |
|---|---|
| SessionStart | `api seed --pid {parent_pid} --session-id {session_id}` then `api listen <id>` |
| Stop / Idle | `api state idle` (and `api state busy` on activity) |
| PreCompact / clear | `api boundary <clear\|compact> <id> --to-session-id <sid>` |
| SessionEnd | `api session-end <id>` (or `api shutdown <id>` for graceful final echo-commune) |
| UserPromptSubmit | **gap F-001 #1/#3** — not published |
| PreToolUse | **gap F-001 #1/#3** — not published |
| SubagentStart / SubagentStop | `api worker-start/worker-stop` exist but **not mapped** (gap F-001 #1) |

## Gate

`traceable-reqs check` EXIT=0 with the skeleton milestone's reqs activated and covered, the
skeleton plugin installable from a local marketplace clone, and the manifest validating against
the published schema. Build/CI wiring is a separate milestone.
