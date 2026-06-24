---
name: commune
description: |
  Push a context update to your Psyche so it can brief your resume across a reset. Use when the
  user says "commune" or "update psyche", or — as a live agent — after a significant body of work,
  before a /clear or /compact. Pass --checkpoint to ALSO auto-clear and wake yourself from the
  freshest commune (an agent-driven context reset, no operator needed).
allowed-tools: [Bash, Write]
---

<!-- [doc->REQ-DIST-CHECKPOINT-COMMUNE] -->

# /sptc:commune

Brief your Psyche with a context DELTA so it can carry you across a `/clear` or compact. **Live
agents only** — a ready agent has no Psyche and nothing to rebuild from.

This is a **file-drop, not an `api` verb**: you write the file, spt's daemon ingests it into your
tracked mind, then deletes it. The file disappearing is the success signal.

## Normal commune

1. Get your id: `spt whoami` (empty ⇒ no perch — run `/sptc:live` first).
2. Write `.claude/<id>-commune.md` in ONE atomic write — a concise delta, not a transcript:
   - current task + status,
   - decisions made since your last commune,
   - immediate next steps (so your post-reset self resumes without re-deriving).
3. If the file lingers instead of disappearing, you are not live (no daemon ingesting it).

## Checkpoint (`--checkpoint`) — self-initiated context reset

A **checkpoint** is a commune that ALSO asks spt to wipe and rebuild your working context from that
very commune — the agent-driven sibling of the operator manually running `/clear`. Use it when your
context is getting long but you are mid-task and want to keep going coherently on your own.

You request a checkpoint by embedding the literal **`!!checkpoint!!`** trigger in the commune body
(the `--checkpoint` flag is just the cue to do this). Author the commune INLINE, right now, in this
same turn — you are the authoring agent, pre-clear. Do NOT defer authoring to after the clear.

Wake directive — what your resumed self is told to do first:

- **One `!!checkpoint!!`** anywhere in the body ⇒ checkpoint with the DEFAULT wake,
  `Proceed with next steps`.
- **A PAIR of `!!checkpoint!!` markers** ⇒ the text BETWEEN them is your CUSTOM wake directive, e.g.

  ```
  !!checkpoint!! Resume T2c: wire the binary checkpoint branch against doyle's reply. !!checkpoint!!
  ```

  rebuilds your context, then wakes you with exactly that instruction.

Mechanics (you don't drive these — they fire automatically once the file lands): your perch is marked
idle, a reserved checkpoint signal self-sends back through your own endpoint, and the delivery layer
runs the clear + wake. The commune you just wrote is what your Psyche rebuilds you from, so make it
complete. **spt-hosted live sessions only** (the self-send loopback needs the broker-held PTY).

Steps for a checkpoint:

1. `spt whoami` for your id (empty ⇒ not live; checkpoint is unavailable).
2. Write `.claude/<id>-commune.md` with your full resume delta AND the `!!checkpoint!!` trigger
   (single for the default wake, or a pair bracketing your custom wake).
3. The clear + wake fire on their own. Your next turn is the post-checkpoint wake — continue from the
   commune.
