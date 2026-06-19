# /sptc:version — operative instructions

Report the **version-of-truth** — the spt-core-tracked binary + adapter manifest, NOT the marketplace
`plugin.json` version.

1. `spt --version` — the binary.
2. `spt adapter list` — the registered `claude-spt` entry + active profile (what drives the session).
3. Note that the cplugs plugin version is intentionally not the version-of-truth.
