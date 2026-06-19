# /sptc:send — operative instructions

**Goal:** deliver a message to another spt agent. The message **body is read from stdin**.

**Do this:**

1. If `spt` is not on `PATH`, run `/sptc:setup` first.
2. Fire-and-forget: `printf '%s' "<body>" | spt send <target>`.
   - `SENT:<target>` = delivered live. `QUEUED:<target>` = target not listening; spooled, drains on
     its next `spt ready`. **QUEUED is success — do not retry.**
3. Reply to a message you received: `... | spt send --reply-to <sender>` (`<sender>` = the envelope's
   `from` attribute; prints `REPLIED:<sender>`).
4. Send and wait for a reply: `... | spt ring <target> --timeout 60` (reply prints to stdout;
   `TIMEOUT` is exit 0 — the message still landed, the reply arrives on your listener).

Your sender id is auto-detected; `--from <id>` overrides. To receive replies, run `/sptc:ready` first.
