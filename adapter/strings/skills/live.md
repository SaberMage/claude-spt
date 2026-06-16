# /sptc:live — operative instructions

> Delivered file-backed via the `claude-spt` adapter `[strings]`
> (`[strings.skills].live = { file = "skills/live.md" }`), resolved at injection time. The cplugs
> SKILL.md stays a thin skeleton (ADR-0001).

**Goal:** upgrade THIS Claude Code session to a **LiveAgent** — a reachable agent whose context is
backed by a **Psyche** (the daemon-managed companion that briefs your resume across `/clear`/compact
via commune deltas). This is NOT spawning a separate or nested session; it is making the session you
are in right now live.

**How a session becomes live (no "go-live" verb — doyle 2026-06-15, traced spt-core):** LiveAgent vs
ReadyAgent is gated entirely by the resolved manifest declaring `[session.psyche_init]`. Base
`claude-spt` declares none (= ReadyAgent, like `/sptc:ready`); the `claude-spt:live` profile overlays
it (= LiveAgent). Selecting the `:live` composite at seed time is what tells the spt-core daemon to
spawn this endpoint's Psyche. The Psyche is **daemon-managed by contract** — do NOT try to start,
poll, or tear down the Psyche yourself; the daemon owns its whole lifecycle.

**Do this:**

1. If `spt` is not on `PATH`, run `/sptc:setup` first.
2. If `spt how-to live` exists (run it; today it returns `NO_SUCH_TOPIC` — there is no published
   live topic yet, **F-007**), prefer that canonical, always-current guidance. Until it lands, the
   operative summary below is the floor — follow it directly.
3. Operative summary:
   - Pick a short lowercase perch id, or reuse this session's id from `spt whoami`. Call it `<id>`.
   - Seed/select the LiveAgent profile so the daemon resolves `[session.psyche_init]` and spawns the
     Psyche: bring the perch up under the **`claude-spt:live`** composite adapter (the `:live` overlay),
     not the bare `claude-spt`. (The SessionStart seed uses the base adapter for a ReadyAgent;
     `/sptc:live` is the one path that activates the `:live` composite.)
   - Run the **delivery relay** as a long-running **background task** (CC's Monitor) and read its
     stdout: `spt api --adapter claude-spt:live listen <id>`. It **blocks** for the session's life —
     the spooled backlog drains first, then each delivery streams in as it arrives. This resident
     relay IS the live delivery pipe.
4. **Poll/relay reconcile (important — avoids double-delivery):** while the Monitor relay is up it is
   the *single* delivery pipe. The `UserPromptSubmit` `api poll` hook must NOT also drain — the relay
   already owns the stream. Treat a running relay as authoritative; the per-prompt poll no-ops while
   it is live, and resumes only if the relay goes down.
5. Delivery shape on the relay stream is the `<EVENT type="msg" from="<sender>">body</EVENT>` envelope
   (body HTML-escaped, newlines as `<br>`). To reply, pipe the body to `spt send --reply-to <sender>`.
6. **Commune across boundaries:** as a live agent you now have a Psyche — use `/sptc:commune` to push
   a context delta before a `/clear` or compact so your resume is briefed. To go offline gracefully
   (tears the Psyche down with the perch), use `/sptc:force-stop` (`spt endpoint shutdown`).

> The Psyche runner (`claude-spt-psyche`, declared in `[profiles.live.session.psyche_init]`) is the
> resident headless-`claude` companion the daemon launches detached — it keeps a Psyche `claude`
> session alive (one `--continue` turn per daemon pulse) and authors commune drops. You never invoke
> it directly; the daemon does.
<!-- [doc->REQ-SKILL-LIVE] -->
