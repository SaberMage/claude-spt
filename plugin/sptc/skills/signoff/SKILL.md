---
name: signoff
description: |
  Gracefully shut down your live session, saving a final context summary. Use when the user says
  "sign off" or "graceful stop", or when you (a live agent) are done and want to go offline cleanly.
allowed-tools: [Bash, Write]
---

# /sptc:signoff

End your session's endpoint gracefully, with the final context save.

1. (Optional) Write a brief closing summary first, so the saved context is useful on resume.
2. `spt endpoint shutdown` (your own perch by default) — stops the listener, fires the final context
   save, and for a live agent takes the Psyche down with it.
3. Confirm to the user. You are no longer reachable; `/sptc:ready` or `/sptc:live` brings you back.

Lighter, no-save stop: `spt endpoint stop`. Full options: `spt endpoint shutdown --help`.
