# /sptc:ready — operative instructions

> Delivered file-backed via the `claude-spt` adapter `[strings]`
> (`[strings.skills].ready = { file = "skills/ready.md" }`), resolved at injection time. The cplugs
> SKILL.md stays a thin skeleton (ADR-0001).

**Goal:** make this session reachable for inter-agent messages (register a perch and listen).

**Do this:**

1. If `spt` is not on `PATH`, run `/sptc:setup` first.
2. Read the canonical, always-current guidance: run `spt how-to ready` and follow it.
3. Operative summary (from that guidance):
   - Pick a short lowercase perch id, or reuse this session's id from `spt whoami`.
   - Preferred (harness hosts a long-running task): `spt ready <id>` — it **blocks** for the
     session's life, so run it as a **background task** and read its stdout. `READY:<id>` on stderr
     is the online signal; the spooled backlog drains first, then each delivery prints as it arrives.
   - Fallback (no long-running tasks): `spt ready <id> --once` — drains the backlog, waits for one
     delivery, exits. Re-run after each exit to stay reachable.
4. Delivery shape on stdout is the `<EVENT type="msg" from="<sender>">body</EVENT>` envelope (body
   HTML-escaped, newlines as `<br>`). To reply, pipe the body to `spt send --reply-to <sender>`.
