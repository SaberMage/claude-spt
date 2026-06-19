# /sptc:version — operative instructions

**Goal:** report the **version-of-truth** — the spt-core-tracked binary + adapter-manifest version,
NOT the marketplace `plugin.json` version (the thin skeleton sits static across many binary/manifest
updates, so its version is not authoritative).

**Do this:**

1. If `spt` is not on `PATH`, run `/sptc:setup` first.
2. Report the binary version: `spt --version`.
3. Report the registered adapter (the conducted layer): `spt adapter list` — the `claude-spt` entry
   and its active profile(s). This is what actually drives the session.
4. State plainly that the cplugs plugin version (`plugin.json`) is intentionally NOT the
   version-of-truth; the binary + adapter manifest above are.
