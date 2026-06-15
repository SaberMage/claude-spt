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
- [x] Record spt-core public-surface finding **F-001**; **converged + re-scoped 2026-06-15** with
      doyle (grounded in `CONTEXT.md`): the hook wiring is adapter-authoring (ours), not spt-core
      gaps. Residual spt-core item = publish `api poll` emit-format + sub-key catalog (doyle, non-
      blocking). See `docs/SPT-CORE-FINDINGS.md`.
- [x] **ADR-0002** — hook wiring: hand-written CC `hooks.json` shells `spt api --adapter claude-spt`;
      full CC-event→api mapping; lifecycle (SessionStart seeds, `listen` runs from `/sptc:ready|live`
      not a hook); UPS→`poll`→stdout→`additionalContext`. Grounded in observed 0.6.0 binary + CC
      hook-input schema.
- [x] **Author the hook glue:** `plugin/sptc/hooks/hooks.json` + wrappers (`_common.sh`,
      session-start, user-prompt-submit, stop, session-end, subagent-start/stop) per ADR-0002.
      All `sh -n` clean; hooks.json valid JSON.
- [x] **Hook-side id-resolution** (ADR-0002 Open#1) resolved via `spt whoami`.
- [x] **Parser unit-tested** (`tests/hooks-parse.sh`: `json_str` + `render_frames`, 7/7 pass).
      `REQ-DIST-HOOKS-API` + `REQ-UPS-INJECTION` activated to `[doc,impl,unit]` (`int` held).
- [x] **F-002 resolved-by-design (ADR-0020):** canonical poll format = self-delimiting `<EVENT>`
      envelope (`__REPLY_TO__` relic deleted). Parser retargeted to `<EVENT>` (split on `</EVENT>`,
      `from` attr + `<br>`/entity unescape) — **multi-message built + unit-tested** (10/10). No
      `<EVENT-PART>` reassembly at poll (listener-stream-only). Follow-up: CC `additionalContext`
      10k cap is adapter-side (truncate/spill) — `int` item.
- [x] **`int` validation — CC-side confirmed** (throwaway `claude -p` rig, 2026-06-15):
      `UPS-fires-on-/sptc:X` ✅ (literal `/send hi` in `prompt`, hook fired, skill ran);
      Windows `shell:bash` hooks ✅ (`$CLAUDE_PROJECT_DIR` resolves); stdin schema ✅. Surfaced the
      MSYS `/`-arg hazard → KNOWN-HAZARDS 1.1 + `REQ-HAZARD-MSYS-PATHCONV` (tests/msys-hazard.sh).
- [ ] **`int` remaining — gated on spt-core `REQ-MSG-ENVELOPE`:** the `api poll`→`additionalContext`
      round-trip against a real spt perch (capture `<EVENT>` bytes → confirm-match to doyle → flip
      `int` for HOOKS-API/UPS-INJECTION). Plus large-drain injection-size handling (10k cap).
- [ ] `/sptc:version` operative body + adapter manifest → validate against published
      `manifest.schema.json` (`reference/schema.md`); activate MANIFEST-SCHEMA, SKILL-VERSION.
- [ ] Tag `impl`/`unit` + activate as each surface lands; `traceable-reqs check` EXIT=0.

## Gate

`traceable-reqs check` EXIT=0 with the skeleton milestone's reqs activated and covered, the
skeleton plugin installable from a local marketplace clone, and the manifest validating against
the published schema. Build/CI wiring is a separate milestone.
