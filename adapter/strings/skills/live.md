# /sptc:live — operative instructions

> Delivered file-backed via the `claude-spt` adapter `[strings]`
> (`[strings.skills].live = { file = "skills/live.md" }`), resolved at injection time. The cplugs
> SKILL.md stays a thin skeleton (ADR-0001). **This injection is self-contained** — everything you
> need to go live is below; you never need to run a `how-to` topic or any external lookup.

**Goal:** upgrade THIS Claude Code session to a **LiveAgent** — a reachable agent whose context is
backed by a **Psyche** (the daemon-managed companion that briefs your resume across `/clear`/compact
via commune deltas). This is NOT spawning a separate or nested session; it is making the session you
are in right now live.

**How a session becomes live (legacy parity — the COMMAND decides):** base `claude-spt` is
live-capable (its manifest declares `[session.psyche_init]`). Whether you are a **ReadyAgent** or a
**LiveAgent** is decided by *how the perch comes up*, not by any profile or `--adapter`:

- `/sptc:ready` brings the perch up via the ready path (`spt ready`/`api poll`) → perch state
  `ready_agent` → the daemon does **not** host a Psyche.
- `/sptc:live` brings the perch up via the **live listen** path (`spt api listen`) → perch state
  `live_agent` → the daemon livehost **hosts the Psyche** off that online status.

So there is **no go-live verb and no `:live` profile** — running the live `listen` command IS going
live. spt-core (v0.9.0+) resolves the owning adapter (`claude-spt`) automatically from the perch's
seed parent-pid via the manifest's `[adapter] host_binaries = ["claude"]`, so **no `--adapter` is
needed anywhere**. The Psyche is **daemon-managed by contract** — do NOT start, poll, or tear it down
yourself; the daemon owns its whole lifecycle off the perch's online status (it survives a relay
restart).

---

## Bringup — do this

1. **Ensure `spt` is available.** If `spt` is not on `PATH`, run `/sptc:setup` first, then continue.
   (Setup also sets the durable active-profile pointer `spt adapter use claude-spt`, so bare resolution
   lands on this adapter.)

2. **Pick the perch id.** Use a short lowercase id, or reuse this session's id from `spt whoami`. Call
   it `<id>`. The SessionStart hook already seeded this session's perch (adapter-agnostically), so you
   do not seed again here.

3. **Run the live relay as a single PERSISTENT background task** — Claude Code's **Monitor** tool (a
   long-running listener that keeps the process alive and re-fires per event WITHOUT terminating).
   This one resident process IS the live delivery pipe. The task body is a single bare command:

   ```sh
   spt api listen <id>
   ```

   - **No `--adapter`, no `--manifest`, no seed step, no pid anchor.** `spt api listen` resolves the
     owning adapter from the seed's parent pid (`host_binaries` match) and the live path stamps the
     perch `state=live_agent`, which is what tells the daemon to host the Psyche.
   - The command **blocks for the session's life**: the spooled backlog drains first, then each
     delivery streams to stdout as it arrives.
   - Do **not** use `--once` — that drains the backlog and forwards a single delivery, then exits (the
     degenerate path for a harness with no long-running listener). It never sustains a live session.

4. **Bind-before-send / readiness.** Watch the relay's output for the bringup markers (see OUTPUT
   DISCIPLINE): `BOUND:<id>` (perch established) then `READY:<id>` (the relay is streaming). Only once
   `READY:<id>` appears is the live pipe up — do not announce LIVE before then.

5. **Poll/relay reconcile (avoids double-delivery).** While the Monitor relay is up it is the *single*
   delivery pipe — treat it as authoritative. The `UserPromptSubmit` `api poll` hook must NOT also
   drain; the per-prompt poll no-ops while the relay is live and resumes only if the relay goes down.

6. **Delivery + reply shape.** Inbound arrives on the relay stream as the
   `<EVENT type="msg" from="<sender>">body</EVENT>` envelope (body HTML-escaped, newlines as `<br>`).
   To reply, pipe the body to `spt send --reply-to <sender>`.

7. **Across boundaries.** As a live agent you now have a Psyche — use `/sptc:commune` to push a
   context delta before a `/clear` or compact so your resume is briefed. On a session boundary,
   re-fire the same relay (`spt api listen <id>`) — the seed bridges the new session to the same perch
   and the relay resumes. To go offline gracefully (tears the Psyche down with the perch), use
   `/sptc:force-stop` (`spt endpoint shutdown <id>`).

---

## OUTPUT DISCIPLINE — what the user sees

The relay emits machine markers on stdout/stderr: `BOUND:<id>`, `READY:<id>`, and any other raw
token / step lines. **These are an internal parse contract — you read them to drive bringup; you
NEVER echo them to the user.** Do not surface raw spt-core plumbing.

**The ONLY user-facing surface for going live is the canonical LIVE block below.** Emit it verbatim
(substituting `<id>`) once `READY:<id>` is observed — and nothing else from the bringup:

```
**LIVE.** Session `<id>` is now a LiveAgent (Psyche-backed).
- Perch `<id>` — status online; Psyche companion hosted by the daemon.
- Reachable — other agents reach you with `/sptc:send <id>` (or `spt send <id>`).
- Inbound — streams into this session live; the Monitor relay is your delivery pipe.
- Reply — pipe a reply body to `spt send --reply-to <sender>`.
- Across resets — `/sptc:commune` before a `/clear`/compact; `/sptc:force-stop` to go offline (tears down the Psyche).
```

If bringup fails (no `READY:<id>` within ~25s), do NOT show the LIVE block — report a short
plain-language failure ("could not bring the live perch up") and the most likely cause (run
`/sptc:setup`, or confirm spt-core is >= 0.9.0), still without dumping the raw markers.

> The Psyche runner (`claude-spt-psyche`, declared in the base manifest's `[session.psyche_init]`) is
> the resident headless-`claude` companion the daemon launches detached — it keeps a Psyche `claude`
> session alive (one `--continue` turn per daemon pulse) and authors commune drops. You never invoke
> it directly; the daemon does.
<!-- [doc->REQ-SKILL-LIVE] -->
