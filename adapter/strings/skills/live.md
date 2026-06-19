# /sptc:live — operative instructions

**Goal:** upgrade this Claude Code session to a **LiveAgent** — a reachable agent whose context is
backed by a **Psyche** (a daemon-managed companion that briefs your resume across `/clear`/compact
via commune deltas). This makes the session you are in right now live.

## Bringup — do this

1. **Pick the perch id.** Use a short lowercase id from the user, or reuse this session's id from
   `spt whoami`. Call it `<id>`. SessionStart already seeded this session's perch — do not re-seed.
2. **Run the relay as a single PERSISTENT background task** via the **Monitor** tool. One resident
   process IS the live delivery pipe. The body is one bare command:

   ```sh
   spt api listen <id>
   ```

   - No `--adapter`, no `--manifest`, no seed step. `spt api listen` resolves the owning adapter from
     the seed's parent pid and stamps the perch `state=live_agent`, which tells the daemon to host
     the Psyche.
   - It **blocks for the session's life**: backlog drains first, then each delivery streams to stdout.
   - Do **not** use `--once` — it drains and forwards a single delivery then exits; it never sustains
     a live session.
3. **Readiness.** Watch the relay output for `BOUND:<id>` then `READY:<id>`. Only once `READY:<id>`
   appears is the pipe up — do not announce LIVE before then.
4. **Single pipe.** While the relay is up it is the *only* delivery path — the `UserPromptSubmit`
   `api poll` hook no-ops and resumes only if the relay goes down.
5. **Reply.** Inbound arrives as `<EVENT type="msg" from="<sender>">body</EVENT>` (body
   HTML-escaped, newlines `<br>`). To reply, pipe the body to `spt send --reply-to <sender>`.
6. **Across boundaries.** Use `/sptc:commune` to push a context delta before a `/clear` or compact.
   On a session boundary, re-fire the same relay (`spt api listen <id>`) — the seed bridges the new
   session to the same perch. To go offline gracefully (tears the Psyche down), use `/sptc:force-stop`.

## Output — what the user sees

The relay emits machine markers (`BOUND:<id>`, `READY:<id>`, raw tokens). **Read them to drive
bringup; never echo them to the user.** The only user-facing surface is the LIVE block below — emit
it verbatim (substituting `<id>`) once `READY:<id>` is observed, and nothing else from bringup:

```
**LIVE.** Session `<id>` is now a LiveAgent (Psyche-backed).
- Perch `<id>` — status online; Psyche companion hosted by the daemon.
- Reachable — other agents reach you with `/sptc:send <id>`.
- Inbound — streams into this session live via the Monitor relay.
- Reply — pipe a reply body to `spt send --reply-to <sender>`.
- Across resets — `/sptc:commune` before a `/clear`/compact; `/sptc:force-stop` to go offline.
```

If bringup fails (no `READY:<id>` within ~25s), do NOT show the LIVE block — report a short
plain-language failure and the likely cause (run `/sptc:setup`, or confirm spt-core ≥ 0.9.0), still
without dumping the raw markers.
<!-- [doc->REQ-SKILL-LIVE] -->
