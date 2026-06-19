# /sptc:commune — operative instructions

**Goal:** push a context DELTA to this live agent's Psyche so it can brief a resume across a session
boundary (`/clear` or compact). A ReadyAgent has no Psyche — **live agents only**.

**This is a FILE-DROP, not a command** (there is deliberately no `spt commune`). The daemon watches
the adapter's commune dir (`.claude`), ingests any `<id>-commune.md` it finds, then deletes it.

**Do this:**

1. If `spt` is not on `PATH`, there is no Psyche to commune with — nothing to do.
2. Resolve this session's id with `spt whoami` (empty ⇒ no perch — run `/sptc:live` first). Call
   it `<id>`.
3. Compose a concise DELTA — not the whole history: current task + status, decisions since the last
   commune, immediate next steps.
4. Write it to `.claude/<id>-commune.md` (one atomic write of the full markdown body).
5. **The file disappearing is the success signal** (the daemon ingested it). If it lingers, confirm
   `spt` is live and this endpoint is a LiveAgent.
