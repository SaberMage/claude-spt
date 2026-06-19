---
name: send
description: |
  Send a message to another SPT agent. Use when the user says "send to", "message",
  "tell <agent>", or when you need to reach or reply to another agent yourself.
argument-hint: "<target>"
allowed-tools: [Bash]
---

# /sptc:send

Deliver a message to another agent. The **body is read from stdin**.

- **Send:** `printf '%s' "<body>" | spt send <target>`. `SENT:<target>` = delivered live;
  `QUEUED:<target>` = target offline, spooled for its next listen. **QUEUED is success — do not retry.**
- **Reply** to a message you received: `printf '%s' "<body>" | spt send <sender>` — the sender id is
  the `from` on the `<EVENT>` you received.
- **Send and wait** for a reply: `printf '%s' "<body>" | spt ring <target> --timeout 60` (reply prints
  to stdout; `TIMEOUT` is exit 0 — the message still landed).

Full guidance: `spt how-to send`. To receive replies on your own perch, go `/sptc:ready` or `/sptc:live`.
