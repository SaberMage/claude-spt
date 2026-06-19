# /sptc:force-stop — operative instructions

**Goal:** tear down an spt agent's endpoint — this session's own, or another agent's.

**Do this:**

1. If `spt` is not on `PATH`, there is nothing running to stop.
2. Identify the target id `<id>` — default is this session's own (`spt whoami`), or the agent the
   user named.
3. **Graceful teardown (default):** `spt endpoint shutdown [<id>]` (omit `<id>` for your own perch).
   It soft-stops the listener, takes the suspend edge (the final context save fires), and for a
   **live agent** tears the **Psyche** down with it.
4. **Lighter, no-save:** `spt endpoint stop <id>` — unregisters the perch; the spool is preserved (no
   suspend/save, no Psyche teardown).
5. Confirm which path you took and what is now offline.

**No hard force in core spt** — `endpoint shutdown` is graceful-only and is the correct
teardown-including-Psyche path for v1 (a no-grace primitive is a tracked spt-core gap).
