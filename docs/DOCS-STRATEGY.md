# Documentation strategy

> A **designed-in commitment**, not an afterthought — grounded in research on
> critically-acclaimed developer docs (Stripe, Twilio, the Rust Book, FastAPI, Cloudflare,
> Anthropic, Diátaxis, `llms.txt`, the Google developer style guide). Governs the **shipped
> product docs** (authored as code lands). The planning docs (CONTEXT / ADRs / design docs) are
> internal and separate.
>
> **Where the docs live (the reframe):** docs live in **this same repo** under `docs-site/`.
> CI builds them with **mdBook** and **publishes to GitHub Pages from this repo**, gated against
> drift. (No separate releases/publish repo — source of truth and published site are one repo.)

## The defining constraint: a dual audience

These docs serve **two readers at once** — human developers *and* the **AI dev-agents that
build on or integrate with this project**. This is the design constraint: every artifact is
authored **once in clean markdown** and served in **two depths** (human-rendered + agent-export).
The agent layer is **first-class, not optional** — make it so good that a dev-agent integrates
correctly on the first try.

## Principles (top techniques, prioritized)

1. **Sub-10-minute killer quickstart** — runnable, deterministic, whole-working-thing-first, no
   placeholders. Time-to-first-hello-world is the single most-cited conversion lever.
2. **Diátaxis four-mode separation** — tutorial / how-to / reference / explanation, never mixed
   (mixing is the most-cited cause of confusing docs).
3. **Deterministic, real, copy-pasteable examples everywhere** — no `<YOUR_VALUE_HERE>`
   placeholders; real values that run. Serves humans *and* agents.
4. **Dual-depth agent exports** — `llms.txt` (slim curated index) + `llms-full.txt` (full
   concatenated export), auto-generated in CI, plus markdown content negotiation (a `.md` suffix
   alongside each `.html`, or `Accept: text/markdown`) which cuts agent token use ~90% vs HTML.
5. **One canonical way to do X** — explicitly mark deprecated / alternate paths. Non-determinism
   is fatal for agents.
6. **Complete reference, auto-generated, all error variants** — generate API reference from the
   code for your public surface, plus any machine-readable contract/schema. Generic placeholders
   in reference are a failure mode.
7. **Consistent conversational voice** — adopt the Google developer style guide: second person
   ("you"), active voice, knowledgeable-friend tone.
8. **Explain *why*, not just *what*** — conceptual docs + diagrams for the project's core model
   and state machines.
9. **Stable, never-renamed anchors / URLs** — agents cache links.
10. **Docs-as-product, gated in CI** — generation (API reference, `llms.txt`, schema, CLI help)
    is part of the build so docs can never drift from code. Drift is the #1 most-cited docs
    failure; this kills it structurally.

## Information architecture — by capability vertical

Organize by capability, each vertical carrying the same four Diátaxis modes internally (the
Cloudflare pattern):

**The `/spt:*` skills · `/spt:setup` · the `cc` launcher · ccs profiles · subnet setup · the
`[digest]` extractor.**

Global sequence (Rust Book logic): early runnable project → dependency-ordered concepts →
capstone last. Per-vertical internal template (Django labels × Cloudflare ordering):
`Overview (why + diagram) · Quickstart/Tutorial · How-to guides · Reference (generated) ·
llms.txt`.

## Killer quickstart targets

Define one per audience — e.g. a **human dev** quickstart (the core primitive end-to-end in one
command + minimal config, < 10 min, whole-thing-first then decomposed) and, if you have
integrators, a **dev-agent integrator** quickstart (the minimal "build against this" hello-world
for `<your integration surface>`). Zero placeholders; every value runs.

## Agent-consumable docs

- **`llms.txt` / `llms-full.txt`** — auto-emitted in CI; the slim index answers quick questions,
  the full export feeds deep ingestion. Two-level (Cloudflare pattern): a curated root index that
  fans out to per-vertical `llms.txt`; `llms-full.txt` is CI-concatenated page bodies
  (generation-only, never hand-authored).
- **Markdown content negotiation** + deterministic include/exclude tags so agent exports carry
  the canonical path and drop human-only narrative.
- **Machine-readable contract/schema** (e.g. JSON Schema) at a stable, discoverable path, if your
  project has one — the schema *is* documentation.
- **CLI help as first-class agent docs**, if you ship a CLI — `<cmd> --help` complete, exampled,
  and ideally machine-readable (a `--json` / structured help mode). The CLI surface is a
  documentation surface.

## Site generator: mdBook + custom theme CSS

**mdBook** is the generator. The **shared theme** lives in `docs-site/theme/` (a
Starlight-inspired skin reused across consumer projects — re-point the accent to rebrand);
**Astro Starlight is the styling north star** (copy its look / feel in the theme CSS, not its
toolchain). Raw `.md` is published alongside each rendered page (`/x.html` ↔ `/x.md`) for the
agent-export convention; `llms.txt` / `llms-full.txt` / any schema are static assets at site root.

## CI commitments

Generated reference, the schema, `llms.txt` / `llms-full.txt`, and CLI help exports are
**generated and checked in CI** — a doc-drift gate. The mdBook build + GitHub Pages publish run
in the same pipeline. Doc quality lives on the same footing as tests.

## Anti-patterns to design against (most-cited failures)

Doc / code drift (#1 — solved by CI gating); *what* without *why*; too much setup before first
success; generic placeholders in reference; mixed Diátaxis modes; poor search / navigation;
multiple non-canonical ways to do X (fatal for agents).
