---
name: send
description: |
  Send a message to another SPT agent. Use when the user says "send to", "message",
  "tell <agent>", or when you need to reach or reply to another agent yourself.
argument-hint: "<target>"
allowed-tools: [Bash]
---

<!-- [doc->REQ-DIST-SKELETON-THIN] -->

# /sptc:send

Deliver a message to another agent (**body read from stdin**). The operative reach is delivered by the
adapter, not baked here (thin skeleton — the prose rides `spt adapter update`): a perched session
already carries send/reply in its **SessionStart brief** (the `messaging-perch` block). In short:

- **Send:** `printf '%s' "<body>" | spt send <target>` — `SENT` = live, `QUEUED` = spooled (success, do
  not retry).
- **Reply:** `printf '%s' "<body>" | spt send <sender>` (sender = the `from` on the `<EVENT>` you got).
- No perch yet? `/sptc:ready` (or `/sptc:live`) first, or send-and-wait without one via
  `printf '%s' "<body>" | spt ring <target> --timeout 60`.

Full guidance: `spt how-to send`.
