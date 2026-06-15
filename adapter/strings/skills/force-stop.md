# /sptc:force-stop — operative instructions

> Delivered file-backed via the `claude-spt` adapter `[strings]`
> (`[strings.skills].force-stop = { file = "skills/force-stop.md" }`), resolved at injection time.
> The cplugs SKILL.md stays a thin skeleton (ADR-0001).

**Goal:** tear down an spt agent's endpoint — this session's own, or another agent's.

**Do this:**

1. If `spt` is not on `PATH`, there is nothing running to stop.
2. Identify the target endpoint id `<id>` — default is this session's own (`spt whoami`), or the
   agent the user named.
3. **Graceful teardown (default — the strongest path core offers):**
   `spt endpoint shutdown [<id>]` (omit `<id>` for your own perch). It soft-stops the listener, then
   takes the suspend edge — the final context save fires, AND for a **live agent** the daemon's
   graceful signoff tears down its **Psyche** too (the composite goes down together).
4. **Lighter, no-save:** `spt endpoint stop <id>` — removes the ready marker and unregisters the
   perch; the spool is preserved (no suspend/save, no Psyche teardown).
5. Confirm to the user which path you took and what is now offline.

**No hard force in core.** spt-core has no SIGKILL / no-grace immediate-teardown equivalent of the
legacy 3-step `$LIVE stop`; `endpoint shutdown` is graceful-only and is the correct
teardown-including-Psyche path for v1. (A hard force/no-grace primitive is a tracked spt-core gap —
`docs/SPT-CORE-FINDINGS.md`.)
