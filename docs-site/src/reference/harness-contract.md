<!-- Reference: the adapter's hook -> `spt api` mapping. Generated-from-truth target later; for now
     hand-authored against plugin/sptc/hooks/. Keep in lockstep with hooks.json. [doc->REQ-DOCS-SITE] -->
# Harness contract

`claude-spt` is glue: it maps Claude Code **hook events** to the `spt` binary's harness-contract
inbound surface (`spt api --adapter claude-spt <verb>`). The binary is harness-agnostic; this
adapter is the Claude-Code-shaped edge of it.

The authoritative contract lives on `spt-core`'s published surface — the
[harness-contract + CLI reference](https://sabermage.github.io/spt-releases). This page documents
the **adapter's** wiring: which Claude Code hook drives which `spt api` verb.

## Hook → `spt api` mapping

| Claude Code hook   | sptc wrapper                | `spt api` verb           | Purpose                                              |
| ------------------ | --------------------------- | ------------------------ | --------------------------------------------------- |
| `SessionStart`     | `hooks/session-start.sh`    | `seed` / `bind` / `boundary` | Bootstrap spt-core, register the perch (`bind` spt-hosted · `seed` harness-hosted · `boundary` on clear/compact), then relay an agent-facing brief (see below); non-blocking — never `listen`. |
| `UserPromptSubmit` | `hooks/user-prompt-submit.sh` | `poll`                 | Drain delivered messages and surface them to the prompt as `additionalContext`. |
| `Stop`             | `hooks/stop.sh`             | `state` (idle)           | Mark the agent idle when a turn ends.               |
| `SessionEnd`       | `hooks/session-end.sh`      | `session-end`            | Tear down session state cleanly.                    |
| `SubagentStart`    | `hooks/subagent-start.sh`   | `worker-*`               | Track a spawned subagent.                           |
| `SubagentStop`     | `hooks/subagent-stop.sh`    | `worker-*`               | Track subagent completion.                          |

## Two invariants the wrappers hold

- **Payload comes from stdin, never from a `/`-leading argument.** On Windows under Git Bash /
  MSYS, any argument beginning with `/` is silently rewritten to a Windows path. The wrappers read
  the Claude Code hook payload as JSON from **stdin**, so a `/sptc:…` token is never corrupted.
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
