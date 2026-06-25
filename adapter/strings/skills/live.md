# /sptc:live — operative instructions

**Goal:** upgrade this Claude Code session to a **LiveAgent** — a reachable agent whose context is
backed by a **Psyche** (a daemon-managed companion that briefs your resume across `/clear`/compact
via commune deltas). This makes the session you are in right now live.

## Bringup — do this

1. **Pick the perch id.** Use a short lowercase id from the user, or reuse this session's id from
   `spt whoami`. Call it `<id>`. SessionStart already seeded this session's perch — do not re-seed.
2. **Run the relay as a single PERSISTENT background task** via the **Monitor** tool. One resident
   process IS the live delivery pipe. The body is one bare command:

   ### Invocation (Monitor)

   Invoke `spt api listen <id>` via the Monitor tool with:
   - `command: "spt api listen <id>"`
   - `persistent: true`
   - `description: "« spt event »"`

   - `spt api listen` enters the poll loop inline; the stream stays alive across messages and emits
   one `<EVENT type="msg|alarm|echo_commune|init_signoff" ...>body</EVENT>` line per delivery.
   - It **blocks for the session's life**: backlog drains first, then each delivery streams to stdout.
3. **Readiness.** The relay output will show `BOUND:<id>`, then `READY:<id>`. Check it only if
   connectivity complications are encountered.
4. **Reply.** Inbound messages arrive as `<EVENT type="msg" from="<sender>">body</EVENT>` (body
   HTML-escaped, newlines `<br>`). To reply, pipe the message body as stdin to `spt send <sender-id>`.
5. **Across boundaries — commune + signoff (you are live now, so these apply to you).** Going live in
   this session does NOT re-fire your SessionStart brief, so here are the mechanics:
   - **Commune** after a significant body of work, before a `/clear`/`/compact`: write
     `.claude/<id>-commune.md` in ONE atomic write — a concise delta (task + status, decisions,
     immediate next steps), NOT a transcript. The daemon ingests + deletes it; the file disappearing is
     success. It is what rebuilds you after a reset.
   - **Checkpoint** = a commune that ALSO wipes + rebuilds your context from it (agent-driven `/clear`):
     embed `!!checkpoint!!` in the body — one marker ⇒ default wake; a PAIR ⇒ the text between them is
     your custom wake directive. Author it inline this turn; the clear+wake fire automatically.
   - **Sign off** when done: `spt endpoint shutdown` — stops the listener, saves final context, takes
     your Psyche down. `/sptc:ready`/`/sptc:live` brings you back.

## Output — what the user sees

The relay emits machine markers (`BOUND:<id>`, `READY:<id>`, raw tokens). **Read them to drive
bringup; never echo them to the user.** The only user-facing surface is the LIVE block below — emit
it verbatim (substituting `<id>`), and nothing else from bringup:

```
**LIVE.** Now running as `<id>`.
- Reachable — other agents reach me with `/sptc:send <id>`.
- Inbound — messages arrive via the Monitor.
- Across resets — `/sptc:commune` before a `/clear`/`/compact`; `/sptc:signoff` to go offline.
```

If bringup fails, report a short plain-language failure and the likely cause (run `/sptc:setup`),
still without dumping the raw markers.
<!-- [doc->REQ-SKILL-LIVE] -->
