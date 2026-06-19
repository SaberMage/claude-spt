# /sptc:ready — operative instructions

**Goal:** make this session reachable for inter-agent messages (register a perch and listen).

**Do this:**

1. If `spt` is not on `PATH`, run `/sptc:setup` first.
2. Pick a short lowercase perch id, or reuse this session's id from `spt whoami`. Call it `<id>`.
3. Preferred (harness hosts a long-running task): run `spt ready <id>` as a **background task** and
   read its stdout. It **blocks** for the session's life — `READY:<id>` (stderr) is the online
   signal; the spooled backlog drains first, then each delivery prints as it arrives.
4. Fallback (no long-running tasks): `spt ready <id> --once` — drains the backlog, waits for one
   delivery, exits. Re-run after each exit to stay reachable.
5. Deliveries arrive as `<EVENT type="msg" from="<sender>">body</EVENT>` (body HTML-escaped, newlines
   as `<br>`). To reply, pipe the body to `spt send --reply-to <sender>`.
