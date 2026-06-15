# /sptc:list-agents — operative instructions

> Delivered file-backed via the `claude-spt` adapter `[strings]`
> (`[strings.skills].list-agents = { file = "skills/list-agents.md" }`), resolved at injection time.
> The cplugs SKILL.md stays a thin skeleton (ADR-0001).

**Goal:** show the roster of spt endpoints/agents reachable from this node.

**Do this:**

1. If `spt` is not on `PATH`, run `/sptc:setup` first.
2. Run `spt endpoint list` (equivalently, bare `spt endpoint`). It renders the merged listing —
   every member subnet's endpoints grouped by subnet, with **this session's own endpoint pinned
   distinctly at the top**.
3. Summarize for the user: who is online, their ids, and which is this session. To message one, use
   `/sptc:send <id>`; to become reachable yourself, `/sptc:ready`.
