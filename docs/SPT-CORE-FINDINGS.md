# spt-core public-surface findings

> Per the public-surface-only constraint (`AGENTS.md`, `HANDOFF.md` §1): if a capability needed
> to build the adapter is missing/ambiguous in spt-core's **published** surface (`spt-releases`
> releases + GH Pages docs), that is a **finding** — `spt-core`'s published contract has a gap.
> We report it to the spt-core owner (**doyle**) and do **not** reverse-engineer from legacy
> `claude_skill_owl` or reach into spt-core source. This file is the in-repo log of those findings.

| # | Date | Status | Summary |
|---|------|--------|---------|
| F-001 | 2026-06-14 | **re-scoped 2026-06-15** — most = adapter-authoring (closed); 1 residual spt-core docs item open | Hook-wiring for a CC adapter — boundary clarified |

---

## F-001 — Harness hook-wiring contract incomplete for a Claude Code adapter

**Reported:** 2026-06-14 to doyle (owl). **Status:** awaiting ruling / docs fix.

**What IS published (sufficient):**
- `harness-contract/api.md` — the full `spt api` primitive surface: `seed`, `listen`, `bind`,
  `boundary`, `session-end`, `shutdown`, `state`, `echo-gate`, `presence`, `driven-by`, `poll`,
  `history-log`, `worker-start/poll/stop`, `bind-shell`, `emit`, `owner-shutdown`, `capability`.
- `harness-contract/install-on-demand.md` — install-on-demand bootstrap, exact `sh` + `ps1`
  snippets, canonical installer URLs, env-var customization. **Fully buildable.**
- `harness-contract/integration-checklist.md` + `manifest.md` map: SessionStart →
  `api seed --pid {parent_pid} --session-id {session_id}` then `api listen <id>`; Idle →
  `api state idle|busy`; PreCompact/clear → `api boundary clear|compact <id> --to-session-id <sid>`;
  teardown → `api session-end <id>` / `api shutdown <id>`.

**The gaps:**

1. **Hook-event → `spt api` mapping is incomplete.** No published mapping for **UserPromptSubmit**,
   **PreToolUse**, **SubagentStart**, **SubagentStop**. (`worker-start/stop` exist but are not tied
   to the Subagent hook events.)
2. **Manifest `[hooks.*]` vs harness-native hook config is unspecified.** `manifest.md` declares
   hooks as `[hooks.<event>] fires="api ..." reads=[...] can_inject=bool`, with spt-core performing
   `{key}` substitution from `reads`. It is **silent** on whether spt-core *materializes* the
   harness-native config (Claude Code `hooks.json`) from the manifest, or the adapter author
   hand-writes `hooks.json` that shells out to `spt api`. These imply different substitution models:
   Claude Code delivers hook data as JSON on **stdin**, but the manifest model is spt-core-side
   `{placeholder}` fill — so if `hooks.json` is hand-written, it is unclear who fills
   `--pid {parent_pid}`. (Also reframes the `SCOPE.md` assumption "the plugin ships a `hooks.json`
   calling `spt api`" — it may instead be manifest-declared + spt-materialized.)
3. **Injection mechanism is undocumented.** `can_inject` + an `[inject]` section (methods
   `pty`/`hook`/`relay`/`http`) exist, but there is **no technical detail** on how an adapter emits
   `additionalContext` back through the hook channel. Blocks (a) general mid-session message
   delivery on a prompt/tool hook, and (b) this project's **UPS-injection** skill-instruction design
   (`docs/adr/0001-*`) specifically — it cannot be validated against the public surface until this
   is documented.

**Impact (as first reported):** SessionStart / Stop(idle) / SessionEnd / boundary are buildable now.
UserPromptSubmit + PreToolUse + Subagent wiring + the entire injection path were *thought* blocked.

### Resolution (2026-06-15 — converged with doyle, grounded in `CONTEXT.md`)

The boundary canon (`CONTEXT.md` L52/L181/L112/L149/L137) re-frames F-001: **spt-core is
harness-independent and supplies the agnostic `spt api` primitives + their I/O format; the adapter
authors the harness-specific wiring + output-formatting.** So most of F-001 is **adapter-authoring
work (ours), not an spt-core gap**:

- **Gap 1 (CC-event → api mapping) — OURS, closed.** Which CC hook drives which `api` primitive is
  adapter glue (L181). Owned mappings: SessionStart → `api seed` (+ env aliases); `/sptc:ready|live`
  → `api listen <id>` (the blocking poll loop — *not* SessionStart, which must not block); Stop/Idle
  → `api state idle|busy`; PreCompact/clear → `api boundary`; SessionEnd → `api session-end` /
  signoff → `api shutdown`; SubagentStart/Stop → `api worker-start`/`worker-stop`; UserPromptSubmit
  → `api poll`; **PreToolUse out-of-scope v1** (UPS covers delivery). See `docs/adr/0002-*`.
- **Gap 2 (medium) — OURS, closed.** The `sptc` plugin **hand-writes** its CC `hooks.json` shelling
  `spt api`. spt-core materializing a CC `hooks.json` would violate L52/L181 — it correctly doesn't.
- **Gap 3 (injection HOW) — OURS, closed.** `api poll` emits message frames to **stdout** by design
  (L149) — that IS the hook-injection delivery path; routing/formatting that stdout into CC's
  `additionalContext` channel is adapter glue (L112). The earlier "`can_inject`/`[inject]`
  method-discard is dead code" alarm is **retracted** — it is M2a roadmap staging (stdout/hook only
  now; PTY at M3), and `can_inject` drives the *built* echo-gate/relay fallback (L137) for hooks that
  cannot inject (e.g. CC Stop).
- **CC param-sourcing** ({parent_pid}/{session_id}) — OURS: read off the CC hook-input schema
  (`session_id` is a common stdin field; pid via the hook process). Not an spt-core concern.

**Residual spt-core item (doyle owns; non-blocking):** publish the **agnostic primitives** to the
adapter-facing docs-site — specifically `api poll`'s **emit frame format** (the frame we parse +
format for CC) and the **substitution-key catalog** (currently code-only). doyle verifies against
`CONTEXT.md`/ADRs then propagates (no new design). We will report the **observed** `api poll` frame
format so the publish can confirm-match. Until published we may rely on observed behavior of the
public binary (observable behavior = public surface).
