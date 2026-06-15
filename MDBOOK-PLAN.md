# mdBook docs-site — JIT plan (slice 1)

> Stand up a buildable, themed, drift-gated mdBook docs-site. Activates the `docs-drift` gate and
> mints **REQ-DOCS-SITE** / **REQ-DOCS-DRIFT**. Tight first slice: real (no-placeholder) skeleton
> pages + generated `llms.txt` + drift gate — not the full docs corpus (that fills in per vertical).

## Scope

1. **`docs-site/book.toml`** — wire the shared `theme/theme.css`, title, src dir, GH-Pages-ready
   `site-url`/build-dir. Build output (`docs-site/book/`) is gitignored.
2. **`docs-site/src/`** — minimal Diátaxis-shaped, all-real-content skeleton (per DOCS-STRATEGY):
   - `SUMMARY.md` (the spine)
   - `introduction.md` — what `claude-spt` is + the mental model (one diagram), why it exists.
   - `quickstart.md` — sub-10-min: install the `sptc` plugin → spt-core auto-bootstraps → first
     `/sptc:*` skill. Deterministic, copy-pasteable, no `<PLACEHOLDER>`.
   - `reference/harness-contract.md` — points at the published spt-releases harness-contract + CLI
     reference (public surface), with the sptc adapter's hook→`spt api` mapping table.
   All content true to the current repo (skeleton-honest: mark not-yet-operative surfaces).
3. **`ci/docs/gen-llms.sh`** — generate `docs-site/llms.txt` (curated slim index per DOCS-STRATEGY
   #4) deterministically from `SUMMARY.md` + page H1s. Committed output; regen must be reproducible.
4. **`ci/docs/check-docs.sh`** — drift gate: `mdbook build` succeeds AND `gen-llms.sh` output
   matches the checked-in `llms.txt` (diff = fail). SKIPs cleanly if `mdbook` absent (fleet host
   without the toolchain) — no silent cap, the skip is logged.
5. **Wire** `check-docs.sh` into `ci/run-gates.sh` (replace the `docs-drift` SKIP stub).
6. **`tests/docs-gen.sh`** — UNIT: `gen-llms.sh` is deterministic (two runs identical) and its
   output covers every `SUMMARY.md` page. [unit->REQ-DOCS-DRIFT]
7. **traceable-reqs.toml** — mint `REQ-DOCS-SITE` `["doc","impl"]`, `REQ-DOCS-DRIFT`
   `["doc","impl","unit"]`; add `ci/docs` to `[scan].roots`.
8. **`.gitignore`** — ignore `docs-site/book/` (build artifact).

## Gate

`sh ci/run-gates.sh` ⇒ PASS (docs-drift now active/green) · `traceable-reqs check` green · `mdbook
build docs-site` clean. Atomic commit, `Co-authored by: perri`.

## Out of scope (later slices)

Per-vertical full Diátaxis content (`/sptc:*`, `cc`, subnet, `[digest]`), `llms-full.txt`,
markdown content-negotiation, GH-Pages publish workflow, rustdoc embed. Manifest authoring
(REQ-DIST-MANIFEST-SCHEMA + v0.7.0 `shortcut_basename`) is the NEXT milestone after this.
