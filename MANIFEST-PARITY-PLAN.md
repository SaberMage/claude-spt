# Adapter-manifest + M12 parity — JIT plan (next milestone)

> Fresh milestone after the CI/distribution slices. Authors the CC adapter **manifest** (publish
> target #2, the spt-core registry side) against the REAL v0.7.0 published surface, then the M12
> parity surfaces. NEEDS public-docs research first — run in clean context.

## Public-surface-only (hard constraint — re-read)

Build ONLY from `SaberMage/spt-releases` (v0.7.0) + `https://sabermage.github.io/spt-releases`
(harness-contract, CLI reference, manifest.schema.json, rustdoc, llms-full.txt). NEVER read
spt-core source. A missing capability = a FINDING for doyle/todlando, not a workaround. (AGENTS.md)

## Research first (before authoring)

1. Pull v0.7.0 `manifest.schema.json` from spt-releases — the authoritative shape the adapter
   manifest must validate against. Note required fields, `[adapter]` block, `[strings]` (file-backed
   large bodies), `shortcut_basename`, profiles/hints/`[digest]` extractor.
2. Read the published harness-contract + CLI reference for: `spt adapter` registration verbs,
   `spt endpoint run`, `shortcut_basename` semantics (emits `sptc-<id>` shortcuts), whoami-as-alias,
   adapter:profile fallback addressing.
3. Confirm where the manifest physically lives (spt-core-conducted registry, NOT plugin files —
   ADR-0001/SCOPE) and how it's validated locally.

## Slices (sequence; each its own commit + green gate)

1. **DONE (bd16644)** — **Adapter manifest authoring**. `adapter/claude-spt.toml` ([adapter]+
   shortcut_basename, [hooks.*], [identity], [inject], [digest], [profiles.deep], [strings],
   [[hints]]); vendored `adapter/manifest.schema.json`; manifest-schema gate
   (`ci/manifest/{validate_manifest.py,check-manifest.sh}`, py tomllib|tomli + jsonschema) wired
   into `run-gates.sh`. **REQ-DIST-MANIFEST-SCHEMA** → `[doc,impl,unit]` (int held: real
   `spt adapter add` registration-validation = 2nd layer). Deferred in-manifest with notes:
   `[session]`/roles, `[history]`, `[update]` (file_pull needs a signing key + registry repo not
   on the public surface — a finding).
2. **DONE (c93757d)** — **shortcut_basename** guard. `tests/manifest-shortcut.sh` asserts the
   `sptc` brand (succession seam). **REQ-DIST-SHORTCUT-BASENAME** → `[doc,unit]` (the field is
   declarative config, not impl — the scanner classifies impl by file type; launcher impl +
   real-picker int deferred to the endpoint-run/cc-launcher slice, gated on the v0.7.0 binary).
3. **M12 parity surfaces** (seed REQs per surface as each starts — activate-don't-pre-fail):
   - **DONE (8cd8372)** — `/sptc:whoami` + `/sptc:setup` skill skeletons (the manifest advertised
     both; skeletons now exist, covered by REQ-DIST-PLUGIN-SKELETON + skeleton-validate).
   - **DONE (435e1be)** — **manifest proven against live v0.7.0**. Local spt upgraded to 0.7.0;
     `ci/manifest/registration-int.sh` (SPTC_ACCEPTANCE-gated) green 6/6: `spt adapter add`
     accepted (2nd-layer cross-field validation), shipped `:deep` profile resolves, `[strings]`
     read + overlay observable via `get-string`, clean soft-remove. **REQ-DIST-MANIFEST-SCHEMA →
     [doc,impl,unit,int]**. Cross-field discovery fixed: `[digest]` needs `source` →
     `source="{home}/.claude/projects"`. Findings logged (key catalog + digest rule undocumented).
   - **IN PROGRESS — capability confirmed (F-003 resolved 2026-06-15)** — file-backed `[strings]`.
     Research conclusion REVERSED by live byte-test + doyle/todlando ruling: the mechanism **is
     shipped** in v0.7.0 as a value-position table pointer `key = { file = "rel" }` over
     `adapters/<adapter>/strings/` (lazy-resolved at `get-string`, containment-checked, copied on
     `adapter add`). My avenue search missed it (it's a value-table shape, not a CLI verb / `@file`).
     ADR-0001 dependency **SATISFIED**; residual is docs-only (doyle publishing, PR #13).
     - **DONE (this session)** — pattern proven end-to-end + first two bodies authored:
       `adapter/strings/skills/{whoami,setup}.md` + `[strings.skills].{whoami,setup} = { file = ... }`;
       `registration-int.sh` extended (8/8) — asserts a `{ file }` pointer resolves to FILE CONTENTS
       and an inline sibling prints as-is, vs live v0.7.0. `strings/` resolves next to the manifest
       FILE on `adapter add`. Bodies grounded in the public surface (`spt whoami`; shipped bootstrap).
     - **DONE (this session)** — ready, send, version authored as file-backed bodies + pointers; stubs
       refreshed. ready/send **delegate to `spt how-to ready|send`** (stay current vs published surface);
       version reports the version-of-truth via `spt --version` + `spt adapter list` (ADR-0001).
     - **DONE (this session, triaged vs the v0.7.1 surface)** — signoff (`spt endpoint shutdown` —
       graceful + final context save, exact match) + list-agents (`spt endpoint list` — the roster).
       7/11 skills now operative. (force-stop/list-agents/new-alarm had no `[strings.skills]` entry;
       list-agents now added.)
     - **TODO — remaining 4, classified (don't invent):**
       - **live** — `spt endpoint run` EXISTS but spawns the manifest `[session.self]` command, which
         is unauthored (deferred slice). GATED on `[session.self]` authoring + the run bringup.
       - **force-stop** — core spt has only soft `spt endpoint stop` (perch, spool kept) + graceful
         `endpoint shutdown`; NO force-kill / Psyche-teardown equivalent (the legacy `$LIVE stop`
         3-step). SEMANTICS MISMATCH → defer; candidate finding if force-kill is required.
       - **commune / new-alarm** — ABSENT from the core `spt` v0.7.1 surface (live-agent/Psyche layer,
         the owl/`$LIVE` binary, not core). Not authorable as core-spt skills → defer; likely a
         scope/finding question (does claude-spt reach the Psyche layer, or are these owl-only?).
   - **DONE (this session) — UPS skill-injection branch BUILT.** UPS-fires-on-slash was already
     proven (ADR-0002 validation 2026-06-15: `/sptc:X` fires with token intact on CC 2.1.177) — my
     earlier "still-open" framing was stale. Built: `_common.sh` `sptc_skill_key` (pure, detect
     `/sptc:<skill>` leading-only) + `sptc_inject_skill` (resolve body via `get-string skills.<x>`,
     wrap `<sptc_skill name>`); `user-prompt-submit.sh` now injects BEFORE the perch check (whoami/
     setup need no perch) then drains. Tests: hooks-parse unit (skill_key, 8 cases) + registration-int
     4c (end-to-end `/sptc:whoami` → wrapped body, 9/9 vs live v0.7.0). `setup` SKILL.md is
     self-contained (runs when spt may be absent → injection no-ops; stub is the floor). whoami/setup
     stubs refreshed (stale "not yet operative" removed). `REQ-UPS-INJECTION` `[doc,impl,unit]` stays
     covered; `int` still held — but ONLY on the message-DRAIN half (`api poll` → additionalContext
     round-trip, gated on REQ-MSG-ENVELOPE publish). The skill-injection int is satisfied (4c).
   - **DONE (d1f14ab)** — `[session.self]` + bind path. Authored `[session.self]` (spawns `claude`)
     + `[env.SPT_ENDPOINT_ID]={id}` + the SessionStart bind/seed/boundary branch (`sptc_register_verb`
     → `api bind`, spt-hosted self-register; bind is establishing/intrinsic-auth, --set-session-id
     only, doyle-confirmed). registration-int 10/10. **REQ-DIST-SHORTCUT-BASENAME → [doc,impl,unit]**.
     int deferred: cc-<id> picker still waved + needs a real-claude acceptance spawn (now contract-
     unblocked). The standalone `cc`/`cc-<id>` launcher SCRIPT still TODO (bakes a non-interactive
     `spt endpoint run`); the `[session.self]` it targets is now authored.
   - **DONE (39c05d1)** — digest extractor `claude-spt-digest` (Rust). CC JSONL → digest NDJSON;
     9 cargo tests; ci/digest/build.sh gate. **REQ-DIST-DIGEST-EXTRACTOR → [impl,unit]**. digest-proof
     int deferred behind **F-004** (doyle-confirmed spt-core impl bug: digest-proof --sample passes an
     empty key map, cli.rs:5135; fix in progress). Proven via cargo + source-only Variant A
     (DIGEST_PROOF_OK 5/0). Flips green on doyle's carrying release.

### Still held on spt-core (non-blocking)
- `sptc-<id>` shortcut EMISSION — spt-core picker wave (not in 0.7.0) + needs `[session.self]`.
- REQ-MSG-ENVELOPE poll→additionalContext bus-delivery int — **DONE (v0.7.1, 2026-06-15).** ADR-0020
  published in v0.7.1; byte-capture confirmed `<EVENT>` on the live `api poll` drain (no `__REPLY_TO__`,
  F-002 dissolved), `render_frames` confirm-match. Locked by `ci/hooks/poll-int.sh` (5/5);
  REQ-DIST-HOOKS-API + REQ-UPS-INJECTION `int` flipped green.

### Note: claude-spt is now a REGISTERED adapter artifact on this node (the v1 acceptance proof).
The int test soft-removes it each run; re-add with `spt adapter add adapter/claude-spt.toml`.
Local `spt` is **0.7.0** (operator-upgraded 2026-06-15).

## Still gated on spt-core (non-blocking)

poll→additionalContext bus-delivery `int` — **DONE (v0.7.1).** ADR-0020 published; byte-capture
confirmed the `<EVENT>` envelope on the live `api poll` drain + `render_frames` confirm-match;
`ci/hooks/poll-int.sh` (5/5) locks it; HOOKS-API + UPS-INJECTION `int` green. (Remaining open: the
~10k additionalContext large-drain truncate/spill — lower priority, ADR-0002 Open #2.)

## Gate (every slice)

`sh ci/run-gates.sh` ⇒ PASS · `traceable-reqs check` green. Atomic commits, `Co-authored by: perri`.

## Session state at handoff (2026-06-15)

Shipped this session (all green, gates PASS, 16/16 traceable): CI ACCEPTANCE slice 1
(73677fd/d834611 — real-claude SUT + perch-collision guard, REQ-CI-ACCEPTANCE [doc,impl,int] +
REQ-HAZARD-PERCH-COLLISION); cplugs publish-prep (e28db92 — validate/package skeleton + untracked
a real perch-state leak, REQ-DIST-PLUGIN-SKELETON [doc,impl,unit]); mdBook docs-site
(d999c60/905c62c — drift-gated book + llms.txt, REQ-DOCS-SITE/REQ-DOCS-DRIFT). Collaborators:
doyle (design/gate) + todlando (builds spt-core) over the spt bus. v0.7.0/M12 is PUBLIC.
