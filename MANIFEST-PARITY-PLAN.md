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
   - **BLOCKED-AS-FINDING (F-003, 2026-06-15)** — file-backed `[strings]`. RESEARCH DONE: v0.7.0/M12
     has **no** file-backed mechanism (schema inline `additionalProperties`; `get-string` prints raw
     inline; `set-string` takes a literal `<VALUE>`; `create-profile --from` ingests a whole inline
     overlay; published `llms-full.txt` documents no `@file`/include). ADR-0001's named M12 dependency
     is **unmet by published M12**. Filed F-003 to doyle+todlando; HOLD authoring. Per ADR-0001's own
     fallback, the `/sptc:whoami`+`/sptc:setup` skeletons keep **interim inline bodies**; the manifest
     does not externalize skill bodies in v0.7.0. `REQ-UPS-INJECTION` stays `[doc,impl,unit]` (the
     externalization half is held on this capability, not failed).
   - **TODO** `[session.self]` + `spt endpoint run` bringup + `cc`/`sptc` launcher → unblocks the
     held **REQ-DIST-SHORTCUT-BASENAME** impl+int (the `<basename>-<id>` picker "lands in a later
     spt-core wave" per `endpoint run --help`; `endpoint run` spawns `[session.self]`, still deferred).
   - **TODO** digest extractor binary `claude-spt-digest` → unblocks `spt adapter digest-proof`
     (the deeper [digest] int; the seam is declared + registration-accepted, extractor unbuilt).

### Still held on spt-core (non-blocking)
- `sptc-<id>` shortcut EMISSION — spt-core picker wave (not in 0.7.0) + needs `[session.self]`.
- REQ-MSG-ENVELOPE poll→additionalContext bus-delivery int — doyle pings for byte-capture when
  todlando lands the ADR-0020 relic removal; I owe a confirm-match + a HOOKS-API/UPS-INJECTION int flip.

### Note: claude-spt is now a REGISTERED adapter artifact on this node (the v1 acceptance proof).
The int test soft-removes it each run; re-add with `spt adapter add adapter/claude-spt.toml`.
Local `spt` is **0.7.0** (operator-upgraded 2026-06-15).

## Still gated on spt-core (non-blocking)

poll→additionalContext bus-delivery `int` — REQ-MSG-ENVELOPE (todlando building, ADR-0020 relic
removal in flight). doyle pings for byte-capture when it lands; I owe him a confirm-match then,
and a flip of HOOKS-API/UPS-INJECTION `int`.

## Gate (every slice)

`sh ci/run-gates.sh` ⇒ PASS · `traceable-reqs check` green. Atomic commits, `Co-authored by: perri`.

## Session state at handoff (2026-06-15)

Shipped this session (all green, gates PASS, 16/16 traceable): CI ACCEPTANCE slice 1
(73677fd/d834611 — real-claude SUT + perch-collision guard, REQ-CI-ACCEPTANCE [doc,impl,int] +
REQ-HAZARD-PERCH-COLLISION); cplugs publish-prep (e28db92 — validate/package skeleton + untracked
a real perch-state leak, REQ-DIST-PLUGIN-SKELETON [doc,impl,unit]); mdBook docs-site
(d999c60/905c62c — drift-gated book + llms.txt, REQ-DOCS-SITE/REQ-DOCS-DRIFT). Collaborators:
doyle (design/gate) + todlando (builds spt-core) over the spt bus. v0.7.0/M12 is PUBLIC.
