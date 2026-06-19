# /sptc:force-stop — operative instructions

Tear down an spt agent's endpoint — your own, or another agent's.

1. Target id `<id>`: your own (`spt whoami`) by default, or the one the user named.
2. **Graceful (default):** `spt endpoint shutdown [<id>]` — stops the listener, fires the final save,
   and for a live agent takes its Psyche down too.
3. **Lighter, no-save:** `spt endpoint stop <id>` — unregisters the perch; the spool is preserved.

Confirm what is now offline. Options: `spt endpoint --help`. (No hard/no-grace kill in core spt —
`shutdown` is the strongest path.)
