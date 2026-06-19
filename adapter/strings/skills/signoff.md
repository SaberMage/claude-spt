# /sptc:signoff — operative instructions

**Goal:** gracefully shut down this session's endpoint, with the final context save.

**Do this:**

1. If `spt` is not on `PATH`, there is no endpoint to sign off — nothing to do.
2. (Optional) Write a brief closing summary first, so the saved context is useful on resume.
3. Run `spt endpoint shutdown` (defaults to this session's own perch): it soft-stops the listener,
   then takes the suspend edge — **the final context save fires** — and persistent shells cascade
   offline with it.
4. Confirm to the user. The session is no longer reachable for messages; `/sptc:ready` (or a fresh
   `spt endpoint run`) brings it back.

For a lighter stop without the suspend/save (spool preserved), use `spt endpoint stop <id>` — but
signoff is the graceful, context-saving path.
