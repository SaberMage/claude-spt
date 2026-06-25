---
name: signoff
description: |
  Gracefully shut down your live session, saving a final context summary. Use when the user says
  "sign off" or "graceful stop", or when you (a live agent) are done and want to go offline cleanly.
allowed-tools: [Bash, Write]
---

<!-- [doc->REQ-DIST-SKELETON-THIN] -->

# /sptc:signoff

**Live agents only.** No perch (`spt whoami` is empty)? Nothing to sign off.

The operative steps are delivered by the adapter, not baked here (thin skeleton — the prose rides
`spt adapter update`; ADR-0001/ADR-0006): a live agent carries them in its **SessionStart brief** (the
`live-ops` block) and the **`/sptc:live` go-live body**. In short: optionally write a brief closing
summary, then `spt endpoint shutdown` (your own perch) — stops the listener, fires the final context
save, takes your Psyche down. `/sptc:ready` or `/sptc:live` brings you back; lighter no-save stop is
`spt endpoint stop`.
