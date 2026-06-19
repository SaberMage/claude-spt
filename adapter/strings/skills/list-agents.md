# /sptc:list-agents — operative instructions

**Goal:** show the roster of spt endpoints/agents reachable from this node.

**Do this:**

1. If `spt` is not on `PATH`, run `/sptc:setup` first.
2. Run `spt endpoint list` (or bare `spt endpoint`): every member subnet's endpoints, grouped by
   subnet, with **this session's own endpoint pinned distinctly at the top**.
3. Summarize who is online, their ids, and which is this session. To message one use
   `/sptc:send <id>`; to become reachable yourself, `/sptc:ready`.
