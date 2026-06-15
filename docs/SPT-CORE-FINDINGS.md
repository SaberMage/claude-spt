# spt-core public-surface findings

> Per the public-surface-only constraint (`AGENTS.md`, `HANDOFF.md` §1): if a capability needed
> to build the adapter is missing/ambiguous in spt-core's **published** surface (`spt-releases`
> releases + GH Pages docs), that is a **finding** — `spt-core`'s published contract has a gap.
> We report it to the spt-core owner (**doyle**) and do **not** reverse-engineer from legacy
> `claude_skill_owl` or reach into spt-core source. This file is the in-repo log of those findings.

| # | Date | Status | Summary |
|---|------|--------|---------|
| F-001 | 2026-06-14 | reported → doyle | Hook-wiring contract for a CC adapter is incomplete (3 sub-gaps) |

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

**Impact:** SessionStart / Stop(idle) / SessionEnd / boundary are buildable now. UserPromptSubmit +
PreToolUse + Subagent wiring + the entire injection path are blocked pending docs. `hooks.json` and
the UPS-injection design are held.
