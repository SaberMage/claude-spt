# CHECKPOINT-COMMUNE-PLAN.md — JIT plan

> Two operator-requested features + one foundational parity gap they surfaced. Grilled with
> doyle (spt-core) to map the public-surface boundary; design is locked against frozen contracts.
> Authored 2026-06-24 (perri). Companion ADR: `docs/adr/0004-checkpoint-via-self-send-loopback.md`
> (to write). Glossary terms landed in `CONTEXT.md` (`checkpoint`, `checkpoint trigger`).

## Scope

Three deliverables, separable:

1. **Feature 1 — multi-line `<EVENT>` envelope** (cosmetic; visual distinction of inbound idle msgs).
2. **Feature 2 — checkpoint communes** (agent-driven context-compaction: flagged commune → auto
   `/clear` → wake; re-seed carried by spt-core's resume verb).
3. **Parity wiring — `psyche-download` at SessionStart** (foundational; closes a pre-existing gap
   where claude-spt live agents get NO durable resume context today — only the identity brief).

## Hard public-surface findings (logged separately)

- **F-0xx psyche-download verb absent** — `download_psyche_context` (spt-core resume.rs:88) is
  exported-but-unexposed (zero `ApiCmd` callers). No published `spt` verb let an adapter pull resume
  context. CONFIRMED spt-core gap. **RESOLVED-PENDING: v0.15.0 W5** exposes the verb (frozen contract
  below) + W4 doc work. Foundational — claude-spt resume context is broken without it.
- **F-0xx PreToolUse poll missing** — claude-spt polls only on `UserPromptSubmit` (between turns).
  Legacy spt also polls+injects on **PreToolUse** = the mid-turn message-delivery half of live-agent
  reachability. Standalone parity gap; not yet wired here.
- **F-0xx subagent-perch reachability** — wiring is present (`subagent-start.sh` → `api worker-start`,
  `hostable_types` includes `Worker`); runtime reachability (`spt send` to a worker) is UNVERIFIED.
  Validation item, not a known gap.

## Frozen contracts to build against

### A. `{text}` is byte-verbatim (doyle, this thread)
spt-core writes `{text}` to the PTY verbatim **including `\n`**; `{key:enter}`→`\r`. There is NO
win32 key-encoding in spt-core (the DECSET-9001 theory was debunked F-019 misdirection). Whether CC
renders a raw `\n` as a soft-newline vs submit is **CC's behavior = our empirical test** (T1 below).
`{key:"shift+enter"}` is NOT recognized (key_to_bytes → None → silently skipped) — do not use.
Doc-gap (key-vocab not enumerated; `{text}`-verbatim unstated) → doyle folding into **v0.15.0 W4**.

### B. `psyche-download` resume verb — FROZEN Tier-1 (doyle, operator-approved; ships v0.15.0 W5)
```
spt api psyche-download <id> [--session-id <sid>]
  <id>         = self/agent id
  --session-id = optional (rotated SessionStart sid, for stamping; accepted, may be unused Tier-1)
  auth-gated like sibling id-scoped verbs (api poll / api presence) — pass link/auth token as
    trailing arg IFF our other api calls do
  project resolved internally from the endpoint's bound cwd — NO --project arg

STDOUT (inject VERBATIM as SessionStart additionalContext):
  <live-role>…</live-role>                       (if a role authored; else omitted)
  <live-context>…</live-context>                 (durable agents/<id>/live-context.md)
  <project-context-resolved name="<proj>"/>      (sentinel — present iff in a resolved project)
  <project-context>…</project-context>           (durable projects/<proj>/<id>/project-context.md)
  <pending-commune>…raw drop body…</pending-commune>   (ONLY if not-yet-synthesized; TRIGGER STRIPPED core-side)
  <pending-signoff>…raw drop body…</pending-signoff>   (likewise for signoff)

Empty/no-context → NO-CONTEXT signal on stderr (mirrors legacy $LIVE psyche-download) → inject nothing.
```
FRESHNESS: `<pending-*>` present iff a drop is not-yet-synthesized → one call always returns
durable + freshest un-synthesized delta. Race-free (core owns read+ingest; no adapter TOCTOU).
Self-clearing (post-synthesis the slice vanishes; no dup).
DEFERRED Tier-2 (NOT in verb yet, additive-forward): `<psyche-stamp/>`/`<current/>`/drift-directive,
`<memformat>`, Pulse Log. Separate parity item.

## Design decisions & invariants (the grill output)

- **Cyan color is impossible.** SGR bytes in `{text}` are eaten by CC's input box (win32-input-mode);
  CC user-turns are theme-fixed; no markdown/setting/control-seq colors a turn. PROVEN empirically +
  CC-guide. → multi-line plain-text framing is the only visual-distinction path. NO finding logged
  (operator: skip the color finding).
- **Self-send loopback works** (PROVEN this session): `spt send --from <id> <id>` routes through the
  endpoint's OWN translation binary and lands as a delivered EVENT. This is the checkpoint trigger path.
- **INLINE-PRE-CLEAR INVARIANT (load-bearing, ADR-worthy):** the agent authors+drops its commune
  INLINE during its own `/sptc:commune --checkpoint` turn (it IS the authoring LLM, pre-clear); the
  hook fires `/clear` strictly AFTER the file is on disk. This is doyle's "Shape 1" — the
  psyche-stale-after-clear gap does NOT apply. If checkpoint is ever rerouted through the
  boundary/resume-Self refresh path ("Shape 2"), the stale gap returns. Never defer authoring to post-clear.
- **Trigger marker = literal `!!checkpoint!!`** (operator-specified). ONE = checkpoint w/ default
  wake; a PAIR brackets a custom wake directive. **Strip is core-side** (todlando, W5 verb @20bfc1f):
  the verb's `<pending-commune>` arrives with all `!!checkpoint!!` tokens stripped, inter-marker text
  kept — no adapter strip. (Open: durable-ingest strip so the marker doesn't persist in
  live-context.md post-synthesis — doyle/todlando's call.)
- **Re-seed is core-owned** — no adapter-side raw drop reading (would TOCTOU core's pulse-delete,
  ingest.rs:161). The single `psyche-download` call carries durable + pending.

## Tasks

### T1 — Feature 1: multi-line envelope (binary) · REQ-DIST-IDLE-TRANSLATE (extend)
- **Empirical gate first:** verify CC soft-newlines on a raw `\n` in `{text}` (throwaway probe binary
  emitting `{text:"A"}{key? no}` → `{text:"A\nB"}` …; confirm ONE user turn, two lines, no early submit).
- If confirmed: `commands_for_event` splits the envelope into `opening-tag` `\n` `body` `\n`
  `closing-tag` (newline after the first `>`, before the final `</EVENT>`), embedding raw `\n` in `{text}`.
- Relax the CR/LF→space sanitizer for CC (it's over-defensive per doyle) — but only after T1 verify;
  keep neutralizing genuinely stray/internal newlines that would split the injection.
- Update the 11 binary tests.

### T2 — Feature 2: checkpoint mechanics
- **T2a `/sptc:commune` → full-fat skill doc + `--checkpoint`** (plugin/sptc/skills/commune/SKILL.md;
  drop the fetch-stub form so live agents are natively aware). Document: single `!!checkpoint!!` =
  default wake "Proceed with next steps"; DOUBLE markers = the text between them is the custom wake.
  Add a `[[hints]]` entry. Verify the commune body format matches the daemon's two-slice
  `<live-context>/<project-context>` envelope (or document the freeform→ingest behavior).
- **T2b PostToolUse hook (NEW)** — matcher Write; on Write of `.claude/<id>-commune.md`: scan
  `tool_input.content` (NOT a file re-read) for `!!checkpoint!!`; if present → `spt api state idle`
  → `spt send --from <id> <id> <wire-sentinel[+wake-text]>`. Resolve `<id>` (SPT_ENDPOINT_ID / whoami);
  guard to spt-hosted live endpoints only. Add `[hooks.PostToolUse]` to manifest + hooks.json.
  - **Wire-sentinel format:** `<reserved-prefix><wake-text>` (e.g. `__SPTC_CHECKPOINT_v1__…`),
    single-line-safe through the EVENT envelope; empty tail → default wake. Parse the double-marker
    inner text from `tool_input.content`.
- **T2c binary checkpoint branch** — `commands_for_line`: if the envelope body matches the
  wire-sentinel prefix → emit the clear+wake macro INSTEAD of normal delivery:
  `ctrl+s · 50ms · /clear · enter · 500ms · <wake-text> · enter · commit` (leading `ctrl+s` REQUIRED
  to stash lingering input; `<wake-text>` = parsed custom or default). New REQ (e.g.
  REQ-DIST-CHECKPOINT-MACRO).

### T3 — Parity wiring: psyche-download at SessionStart · new REQ (e.g. REQ-DIST-RESUME-CONTEXT)
- session-start.sh: on bind|boundary (perched), after existing logic, run
  `spt api psyche-download <self-id> [--session-id <sid>]`; inject stdout as additionalContext;
  skip on NO-CONTEXT (stderr). Boundary stays rotation-only (unchanged). Build against frozen
  contract B; **validate end-to-end only when v0.15.0 W5 ships** (doyle pings).

## Dependencies / sequencing

- T1 buildable+testable now (contract A frozen; needs the empirical gate).
- T2 buildable+testable now (self-send proven; mechanics have ZERO spt-core dep — the clear+wake
  fires regardless). Re-seed RICHNESS depends on T3+W5, but mechanics don't.
- T3 codeable now against frozen contract B; **un-validatable until v0.15.0 W5 ships**.
- PreToolUse poll + subagent-perch-reachability = separate parity items (not in this plan's build).

## Validation gate (per AGENTS.md)

- `cargo build` (binary) green; binary tests green.
- `traceable-reqs check` green (REQs added to `traceable-reqs.toml` FIRST, evidence tagged in-commit).
- T1: live endpoint shows the envelope across lines, one user turn.
- T2: live endpoint — flagged commune → `/clear` fires → wake turn appears (default + custom).
- T3: deferred to W5 ship — `psyche-download` output injected at SessionStart, durable+pending present.

## Open items

- Exact `<id>` + auth-token threading for `api psyche-download` (mirror our other `api` calls).
- Commune body format (two-slice envelope vs freeform) — confirm in T2a.
- Macro 500ms timing adequacy post-`/clear` (validate in T2).
