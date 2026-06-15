# /sptc:version — operative instructions

> Delivered file-backed via the `claude-spt` adapter `[strings]`
> (`[strings.skills].version = { file = "skills/version.md" }`), resolved at injection time. The
> cplugs SKILL.md stays a thin skeleton (ADR-0001).

**Goal:** report the **version-of-truth** — the spt-core-tracked binary + adapter-manifest version,
NOT the marketplace skeleton's `plugin.json` version (ADR-0001: the thin skeleton sits static across
many binary/manifest updates, so its version is not authoritative).

**Do this:**

1. If `spt` is not on `PATH`, run `/sptc:setup` first.
2. Report the spt-core binary version: `spt --version`.
3. Report the registered adapter (the conducted layer's version-of-truth): `spt adapter list` — find
   the `claude-spt` entry and its active profile(s). This is what actually drives the session.
4. State plainly that the cplugs plugin version (`plugin.json`) is intentionally NOT the
   version-of-truth; the binary + adapter manifest above are.
