# /sptc:commune — operative instructions

> Delivered file-backed via the `claude-spt` adapter `[strings]`
> (`[strings.skills].commune = { file = "skills/commune.md" }`), resolved at injection time. The
> cplugs SKILL.md stays a thin skeleton (ADR-0001).

**Goal:** push a context DELTA to this endpoint's Psyche so it can brief a resume across a session
boundary (a `/clear` or compact). Only meaningful for a **live agent** — a ReadyAgent has no Psyche.

**This is a FILE-DROP, not a command** — there is deliberately no `spt commune`. spt-core's daemon
watches the adapter's commune dir (`[session].commune_dir` = `.claude`), ingests any
`<endpoint_id>-commune.md` it finds into the endpoint's tracked mind, then deletes it (the daemon is
the single writer).

**Do this:**

1. If `spt` is not on `PATH`, there is no Psyche to commune with — nothing to do.
2. Resolve this session's endpoint id with `spt whoami` (empty ⇒ no perch — run `/sptc:live` first;
   commune needs a Psyche, i.e. a live agent). Call it `<id>`.
3. Compose a concise DELTA — not the whole history: current task + status, decisions made since the
   last commune, immediate next steps, and anything the Psyche needs to brief a resume.
4. Write it to `.claude/<id>-commune.md` (the watched dir, relative to this project). Use a single
   atomic write of the full markdown body.
5. Confirm to the user. **The file disappearing is the success signal** (the daemon ingested it). If
   it lingers, the watcher isn't running — verify `spt` is live and this endpoint is a LiveAgent.
