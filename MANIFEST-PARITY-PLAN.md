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
     - **TODO (per-skill increments)** — convert the remaining inline summaries (commune, live, ready,
       send, signoff, version) to file-backed bodies as each is authored. ready/send should **delegate
       to `spt how-to ready|send`** (published agent guidance) rather than duplicate.
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
   - **TODO** `[session.self]` + `spt endpoint run` bringup + `cc`/`sptc` launcher → unblocks the
     held **REQ-DIST-SHORTCUT-BASENAME** impl+int (the `<basename>-<id>` picker "lands in a later
     spt-core wave" per `endpoint run --help`; `endpoint run` spawns `[session.self]`, still deferred).
   - **TODO** digest extractor binary `claude-spt-digest` → unblocks `spt adapter digest-proof`
     (the deeper [digest] int; the seam is declared + registration-accepted, extractor unbuilt).

### Still held on spt-core (non-blocking)
- `sptc-<id>` shortcut EMISSION — spt-core picker wave (not in 0.7.0) + needs `[session.self]`.
- REQ-MSG-ENVELOPE poll→additionalContext bus-delivery int — ADR-0020 MERGED to spt-core main
  (`25ffd7a`) but NOT yet PUBLISHED; v0.7.0 still carries the `__REPLY_TO__` relic. Byte-capture tests
  the SHIPPED binary, so the int flip waits for the next RELEASE carrying ADR-0020 (doyle pings with
  the hash on publish), NOT the merge. Parse v0.7.0 as-is until then; then confirm-match + flip
  HOOKS-API/UPS-INJECTION int.

### Note: claude-spt is now a REGISTERED adapter artifact on this node (the v1 acceptance proof).
The int test soft-removes it each run; re-add with `spt adapter add adapter/claude-spt.toml`.
Local `spt` is **0.7.0** (operator-upgraded 2026-06-15).

## Still gated on spt-core (non-blocking)

poll→additionalContext bus-delivery `int` — REQ-MSG-ENVELOPE. ADR-0020 MERGED to spt-core main
(`25ffd7a`) but NOT PUBLISHED; v0.7.0 still emits the `__REPLY_TO__` relic. Byte-capture tests the
SHIPPED binary → int flip waits for the next RELEASE carrying ADR-0020 (doyle pings with the hash on
publish), not the merge. Then confirm-match + flip HOOKS-API/UPS-INJECTION `int`.

## Gate (every slice)

`sh ci/run-gates.sh` ⇒ PASS · `traceable-reqs check` green. Atomic commits, `Co-authored by: perri`.

## Session state at handoff (2026-06-15)

Shipped this session (all green, gates PASS, 16/16 traceable): CI ACCEPTANCE slice 1
(73677fd/d834611 — real-claude SUT + perch-collision guard, REQ-CI-ACCEPTANCE [doc,impl,int] +
REQ-HAZARD-PERCH-COLLISION); cplugs publish-prep (e28db92 — validate/package skeleton + untracked
a real perch-state leak, REQ-DIST-PLUGIN-SKELETON [doc,impl,unit]); mdBook docs-site
(d999c60/905c62c — drift-gated book + llms.txt, REQ-DOCS-SITE/REQ-DOCS-DRIFT). Collaborators:
doyle (design/gate) + todlando (builds spt-core) over the spt bus. v0.7.0/M12 is PUBLIC.
