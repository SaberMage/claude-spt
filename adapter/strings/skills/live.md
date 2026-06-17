# /sptc:live — operative instructions

> Delivered file-backed via the `claude-spt` adapter `[strings]`
> (`[strings.skills].live = { file = "skills/live.md" }`), resolved at injection time. The cplugs
> SKILL.md stays a thin skeleton (ADR-0001). **This injection is self-contained** — everything you
> need to go live is below; you never need to run a `how-to` topic or any external lookup.

**Goal:** upgrade THIS Claude Code session to a **LiveAgent** — a reachable agent whose context is
backed by a **Psyche** (the daemon-managed companion that briefs your resume across `/clear`/compact
via commune deltas). This is NOT spawning a separate or nested session; it is making the session you
are in right now live.

**How a session becomes live (no "go-live" verb):** LiveAgent vs ReadyAgent is gated entirely by the
resolved manifest declaring `[session.psyche_init]`. Base `claude-spt` declares none (= ReadyAgent,
like `/sptc:ready`); the `claude-spt:live` profile overlays it (= LiveAgent). Bringing the perch up
under the `:live` composite is what tells the spt-core daemon to host this endpoint's Psyche. The
Psyche is **daemon-managed by contract** — do NOT try to start, poll, or tear down the Psyche
yourself; the daemon owns its whole lifecycle off the perch's online status (so the companion
survives a relay restart).

---

## Bringup — do this

1. **Ensure `spt` is available.** If `spt` is not on `PATH`, run `/sptc:setup` first, then continue.

2. **Pick the perch id.** Use a short lowercase id, or reuse this session's id from `spt whoami`. Call
   it `<id>`. Use this session's id from `spt whoami` for `<sid>` (the session-id).

3. **Run the live relay as a single PERSISTENT background task** — Claude Code's **Monitor** tool (a
   long-running listener that keeps the process alive and re-fires per event WITHOUT terminating).
   This one resident process IS the live delivery pipe. It seeds the `:live` composite and binds the
   relay in the SAME process so both share one parent-pid anchor (see the INTERIM note below). The
   task body:

   ```sh
   # Anchor pid: spt probes WINDOWS pids. From git-bash, $$ is the MSYS pid (reads as a dead anchor);
   # use the WINPID column from `ps` (col 4) when present, else $$ is already the real pid.
   ANCHOR=$(ps -p $$ 2>/dev/null | awk 'NR==2{print $4}'); case "$ANCHOR" in ''|*[!0-9]*) ANCHOR=$$;; esac
   spt api --adapter claude-spt:live seed   --pid        "$ANCHOR" --session-id "<sid>"
   spt api --adapter claude-spt:live listen --parent-pid "$ANCHOR" "<id>"
   ```

   - The `listen` line **blocks for the session's life**: the spooled backlog drains first, then each
     delivery streams to stdout as it arrives.
   - Do **not** use `--once` — that drains the backlog and forwards a single delivery, then exits (the
     degenerate path for a harness with no long-running listener). It never sustains a live session.
   - On a registered adapter, `--adapter claude-spt:live` resolves the registered manifest, so no
     `--manifest` is needed.

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
   re-fire the same relay (step 3) — the seed bridges the new session to the same perch and the relay
   resumes. To go offline gracefully (tears the Psyche down with the perch), use `/sptc:force-stop`
   (`spt endpoint shutdown <id>`).

> **INTERIM (PREP-4 / spt-core v0.9.0).** The seed+listen-chained-in-one-process step exists only
> because today's seed and listen must share a parent-pid anchor. Once spt-core ships the
> adapter-agnostic seed (SessionStart seeds by pid; `api listen` resolves the owning adapter/profile
> by pid), this collapses to a bare `spt api listen <id>` under Monitor — no shared-pid chaining and
> no `--adapter`. Do not pre-build that path; it activates on doyle's v0.9.0 ship.

---

## OUTPUT DISCIPLINE — what the user sees

The relay and seed emit machine markers on stdout/stderr: `SEEDED:<pid>`, `NO_SEED:<pid>`,
`STALE_SEED:<pid>`, `BOUND:<id>`, `READY:<id>`, plus any raw token / step lines. **These are an
internal parse contract — you read them to drive bringup; you NEVER echo them to the user.** Do not
surface raw spt-core plumbing.

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

If bringup fails (e.g. `NO_SEED`/`STALE_SEED` and no `READY:<id>` within ~25s), do NOT show the LIVE
block — report a short plain-language failure ("could not bring the live perch up") and the most
likely cause (stale pid anchor, or run `/sptc:setup`), still without dumping the raw markers.

> The Psyche runner (`claude-spt-psyche`, declared in `[profiles.live.session.psyche_init]`) is the
> resident headless-`claude` companion the daemon launches detached — it keeps a Psyche `claude`
> session alive (one `--continue` turn per daemon pulse) and authors commune drops. You never invoke
> it directly; the daemon does.
<!-- [doc->REQ-SKILL-LIVE] -->
