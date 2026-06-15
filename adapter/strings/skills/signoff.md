# /sptc:signoff — operative instructions

> Delivered file-backed via the `claude-spt` adapter `[strings]`
> (`[strings.skills].signoff = { file = "skills/signoff.md" }`), resolved at injection time. The
> cplugs SKILL.md stays a thin skeleton (ADR-0001).

**Goal:** gracefully shut down this session's own endpoint, with the final context save.

**Do this:**

1. If `spt` is not on `PATH`, there is no endpoint to sign off — nothing to do.
2. (Optional) Write a brief closing summary of the session's state first, so the saved context is
   useful on resume.
3. Run `spt endpoint shutdown` (defaults to this session's own perch). It soft-stops the listener,
   then takes the suspend edge — **the final context save fires** and persistent shells cascade
   offline with it.
4. Confirm the shutdown to the user. After signoff this session is no longer reachable for
   inter-agent messages; `/sptc:ready` (or a fresh `spt endpoint run`) brings it back.

To stop the perch WITHOUT the full suspend/save (spool preserved, lighter), use `spt endpoint stop
<id>` instead — but signoff is the graceful, context-saving path.
