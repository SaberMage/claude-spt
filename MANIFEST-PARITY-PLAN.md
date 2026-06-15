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

1. **Adapter manifest authoring** — write the `claude-spt` adapter manifest (`[digest]` extractor,
   profiles, strings, hints, `shortcut_basename=sptc`). Add a **manifest-schema gate** to
   `ci/run-gates.sh` (currently SKIP stub): validate the manifest against the published
   v0.7.0 `manifest.schema.json`. Activate **REQ-DIST-MANIFEST-SCHEMA** → `[doc,impl,unit]`.
2. **shortcut_basename** — wire the `sptc-<id>` shortcut emission; test it. (Mint REQ if needed.)
3. **M12 parity surfaces** (seed REQs per surface as each starts — activate-don't-pre-fail):
   file-backed `[strings]` (skill bodies via UPS-injection, lifts the SKILL.md-skeleton bodies),
   `spt endpoint run` bringup, `cc` launcher, `/sptc:setup`, whoami-as-alias.

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
