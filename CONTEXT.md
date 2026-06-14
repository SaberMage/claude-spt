# spt-claude-code — glossary

> Authoritative for meaning (grill-with-docs convention). Glossary only — no
> implementation detail. Decisions/rationale live in `SCOPE.md` and `docs/adr/`.

**spt-claude-code** — the rebuilt Claude Code harness adapter. The `claude-spt`
adapter in spt-core terms. Simultaneously spt-core's v1 acceptance proof (legacy
parity), its first casual-end-user entrypoint (a CC plugin), and an invisible spt-core
installer. Built by maintainer perri from the public spt-releases surface only.

**claude-spt** — the adapter_name spt-claude-code registers under (rides every `api`
invocation + the manifest). The CC adapter's identity inside spt-core.

**legacy spt / `claude_skill_owl`** — the sister project; today's shipped CC integration
(owl.exe + `spt` plugin, v1.11.25). The parity *target* (user-facing features), not a
1:1 port — most of its machinery now lives in spt.exe.

**skeleton plugin** — the thin marketplace artifact on `SaberMage/cplugs`: namespaced
`/spt:*` skill stubs + hooks + a SessionStart bootstrap that installs spt-core. Low-churn;
the volatile bulk (binary + manifest) is spt-core-conducted, not in the plugin.

**fetch-stub skill** — a `/spt:X` SKILL.md that is a 2-line stub fetching its real
instructions at runtime from the adapter `[strings]` (`spt adapter get-string`/`skill-help`).
Keeps skill files static while instructions update via spt-core. Distinct from a `[hints]`
entry (proactive, keyword-triggered, UPS-hook-delivered).

**ccs profile** — a profile under spt-claude-code (`claude-spt:glm`, `claude-spt:kimi`)
that leaf-replaces the launch command + history/digest log dir to use the `ccs` backend.
NOT its own adapter — ccs is structurally Claude Code.

**`cc` launcher (capsule-style)** — a generated `cc`/`cc <id>` script at project root that
spawns-or-attaches a CC endpoint via spt-core's spt-hosted topology (broker PTY + inject +
attach). The spt-core realization of legacy's unbuilt "Capsule" milestone. _Avoid_: equating
it with psmux/sendkeys — spt-core's broker is the terminal host.

**casual end user** — a user who *uses* an spt-powered system mostly-invisibly, vs the
adapter/shell *developer* who is spt-core's nominal target. spt-claude-code serves casual
users: install the plugin, get spt-core for free.

**experimplate** — the standalone reusable project-workflow template (its own sibling repo)
extracted from spt-core's working style. spt-claude-code is its first consumer. Carries
traceable-reqs gating, JIT plans, grill-with-docs scaffolding, release/changelog, and
same-repo published-docs. Defined in its own folder, not here.
