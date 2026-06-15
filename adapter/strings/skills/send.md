# /sptc:send — operative instructions

> Delivered file-backed via the `claude-spt` adapter `[strings]`
> (`[strings.skills].send = { file = "skills/send.md" }`), resolved at injection time. The cplugs
> SKILL.md stays a thin skeleton (ADR-0001).

**Goal:** deliver a message to another spt agent.

**Do this:**

1. If `spt` is not on `PATH`, run `/sptc:setup` first.
2. Read the canonical, always-current guidance: run `spt how-to send` and follow it.
3. Operative summary (from that guidance) — the message **body is read from stdin**:
   - Fire-and-forget: `printf '%s' "<body>" | spt send <target>`.
     - `SENT:<target>` = delivered live. `QUEUED:<target>` = target not listening; spooled, drains
       on its next `spt ready`. **QUEUED is success — do not retry.**
   - Reply to a received message: `... | spt send --reply-to <sender>` (`<sender>` = the envelope's
     `from` attribute; prints `REPLIED:<sender>`).
   - Send and block for a reply: `... | spt ring <target> --timeout 60` (reply body prints to
     stdout; `TIMEOUT` is exit 0 — the message still landed, the reply arrives on your listener).
4. Your own sender id is auto-detected in most sessions; `--from <id>` overrides. To receive replies
   on your own listener, run `/sptc:ready` first.
