<!-- Reference: the adapter's hook -> `spt api` mapping. Generated-from-truth target later; for now
     hand-authored against tools/claude-spt/src/hook.rs. Keep in lockstep with hooks.json + hook.rs. [doc->REQ-DOCS-SITE] -->
# Harness contract

`claude-spt` is glue: it maps Claude Code **hook events** to the `spt` binary's harness-contract
inbound surface (`spt api --adapter claude-spt <verb>`). The binary is harness-agnostic; this
adapter is the Claude-Code-shaped edge of it.

The authoritative contract lives on `spt-core`'s published surface — the
[harness-contract + CLI reference](https://sabermage.github.io/spt-releases). This page documents
the **adapter's** wiring: which Claude Code hook drives which `spt api` verb.

## Hook → `spt api` mapping

The plugin ships a **static** `hooks.json` that routes every Claude Code hook event through one thin
wrapper, `hooks/dispatch.sh <EventName>`, which resolves the `claude-spt` program (from the adapter's
`[strings].hook_cmd = "{adapter_dir}/claude-spt hook"`, looked up once per session) and runs
`claude-spt hook <EventName>` with the Claude Code hook payload on stdin. The hook **logic lives in
the program** — so it updates with `spt adapter update`, and the plugin's hook wiring stays fixed.

| Claude Code hook   | handler                       | `spt api` verb (representative) | Purpose                                              |
| ------------------ | ----------------------------- | ------------------------------- | --------------------------------------------------- |
| `SessionStart`     | `claude-spt hook SessionStart`   | `seed` / `bind` / `boundary` | Bootstrap spt-core (via dispatch), register the perch (`bind` spt-hosted · `seed` harness-hosted · `boundary` on clear/compact), then relay an agent-facing brief (see below); non-blocking — never `listen`. |
| `UserPromptSubmit` | `claude-spt hook UserPromptSubmit` | `state busy` + `poll`      | Mark the turn busy, drain delivered messages (incl. deferred) to the prompt as `additionalContext`, and inject a `/sptc:…` skill body when present. |
| `PreToolUse`       | `claude-spt hook PreToolUse`     | `state busy` + `poll`        | Mid-turn delivery: drain messages deferred while busy so a live agent receives them *while working*. |
| `Stop`             | `claude-spt hook Stop`           | `state` (idle)               | Mark the agent idle when a turn ends.               |
| `SessionEnd`       | `claude-spt hook SessionEnd`     | `session-end`                | Tear down session state cleanly.                    |
| `SubagentStart`    | `claude-spt hook SubagentStart`  | `worker-*`                   | Track a spawned subagent.                           |
| `SubagentStop`     | `claude-spt hook SubagentStop`   | `worker-*`                   | Track subagent completion.                          |
| `PostToolUse` (Write) | `claude-spt hook PostToolUse` | `state idle` + self-send     | Detect a `!!checkpoint!!` commune Write and self-send the agent-driven checkpoint signal (spt-hosted live agents). |

## Two invariants the handler holds

- **Payload comes from stdin, never from a `/`-leading argument.** On Windows under Git Bash /
  MSYS, any argument beginning with `/` is silently rewritten to a Windows path. The dispatch wrapper
  passes the payload straight through on **stdin** (its only argument is the event name) and the
  program reads the Claude Code hook payload as JSON from stdin, so a `/sptc:…` token is never corrupted.
- **Messages are self-delimiting `<EVENT>` envelopes.** `poll` output is rendered by splitting on
  the canonical `<EVENT type="msg" from="…">body</EVENT>` envelope, so a multi-message drain parses
  cleanly and each message keeps its sender for reply-correlation.

## Identity

Every session resolves its own perch id via `spt whoami`, off `$OWL_SESSION_ID` / `$SPT_AGENT_ID`.
A session with no perch (never made reachable) simply delivers nothing — the per-prompt drain
no-ops rather than erroring.

## SessionStart briefs

`SessionStart` also relays an **agent-facing brief** as `additionalContext`, composed from the
adapter's `[strings.briefs]` (same file-backed/inline machinery as `[strings.skills]`). The hook
only selects + composes + `{id}`-substitutes — it never authors the prose.

| session state | trigger | brief |
| --- | --- | --- |
| has a perch | `bind` (`$SPT_ENDPOINT_ID`) or `boundary` (clear/compact) | **identity brief** — who it is (`{id}`), that its perch is already live (don't re-arm → `COLLISION`), and how to message (`spt send` + reply + the `spt endpoint list` roster). |
| no perch, node has subnet peers | `seed` / fresh startup | **ring brief** — how to reach other agents without a perch (`spt ring <target> --timeout 60`) + the roster. |
| no perch and no peers · subagent (`agent_type` set) | — | nothing. |

The brief is **liveness-agnostic** (no live-vs-ready distinction) pending a published machine-readable
liveness query on the spt surface. The peer gate is a line-count presence check on `spt subnet
status` — it never parses the human-formatted column values.

<!-- [doc->REQ-DIST-SESSIONSTART-BRIEF] -->

> The operative skill instructions are **not** in this plugin. They are delivered by the adapter
> manifest (conducted by spt-core) at invocation time; the `/sptc:*` `SKILL.md` files are
> deliberately thin skeletons. This split keeps the marketplace artifact low-churn while logic and
> instructions update through spt-core's signed adapter-update channel.
