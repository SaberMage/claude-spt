---
name: commune
description: |
  Push a context update to your Psyche so it can brief your resume across a reset. Use when the
  user says "commune" or "update psyche", or — as a live agent — after a significant body of work,
  before a /clear or /compact.
allowed-tools: [Bash, Write]
---

# /sptc:commune

Brief your Psyche with a context DELTA so it can carry you across a `/clear` or compact. Live agents
only (a ready agent has no Psyche).

This is a **file-drop, not a command** — you write the file; spt absorbs it.

1. Get your id: `spt whoami` (empty ⇒ no perch — `/sptc:live` first).
2. Write `.claude/<id>-commune.md` — a concise delta: current task + status, decisions since the last
   commune, immediate next steps. One atomic write of the full body.
3. The file disappearing is the success signal (spt ingested it). If it lingers, you are not live.
