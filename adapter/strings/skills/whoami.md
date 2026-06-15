# /sptc:whoami — operative instructions

> Delivered file-backed via the `claude-spt` adapter `[strings]`
> (`[strings.skills].whoami = { file = "skills/whoami.md" }`), resolved at injection time. The
> cplugs SKILL.md stays a thin skeleton (ADR-0001).

**Goal:** report this session's own spt endpoint (perch) id — "which agent am I?".

**Do this:**

1. Run `spt whoami`. It prints this session's perch id, resolved from `$OWL_SESSION_ID` /
   `$SPT_AGENT_ID`. Report the id plainly.
2. If `spt` is not on `PATH` (`command -v spt` fails), spt-core is not installed — tell the user to
   run `/sptc:setup` first, then retry.
3. If `spt whoami` prints nothing / errors that no perch is bound, this session has not been made
   reachable yet — tell the user to run `/sptc:ready` (or `/sptc:live`) to establish a perch, then
   retry.

Do not invent an id; only report what `spt whoami` returns.
