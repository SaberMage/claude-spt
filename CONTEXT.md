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

**identity brief** — the agent-facing text the adapter injects at SessionStart into a session
that already owns a perch (the `bind` + `boundary` topologies). Tells the agent who it is, that
its perch is already live (so it must not re-arm), and how to message (send + reply + the endpoint
roster). Adapter-string-backed (`[strings.briefs]`), composed from an `{id}`-templated identity
piece plus shared messaging pieces. Liveness-agnostic: it does not distinguish live-vs-ready (that
flavor is deferred until spt-core publishes a machine-readable liveness query). Distinct from the
**ring brief** (the no-perch sibling).

**ring brief** — the SessionStart counterpart for a session with **no** perch (the `seed`
topology): a node-local agent that hasn't readied still learns how to reach other agents via
`spt ring` (the no-id messaging path). Peer-gated — emitted only when the node actually
participates in a subnet (has reachable peers), so a solo casual end user is never told how to
ring agents that don't exist.

**ccs profile** — a profile under spt-claude-code (`claude-spt:glm`, `claude-spt:kimi`)
that leaf-replaces the launch command + history/digest log dir to use the `ccs` backend.
NOT its own adapter — ccs is structurally Claude Code.

**`cc` launcher (capsule-style)** — a generated `cc`/`cc <id>` script at project root that
spawns-or-attaches a CC endpoint via spt-core's spt-hosted topology (broker PTY + inject +
attach). The spt-core realization of legacy's unbuilt "Capsule" milestone. _Avoid_: equating
it with psmux/sendkeys — spt-core's broker is the terminal host.

**Psyche** — a LiveAgent's detached *companion* process. When a session goes live
(`/sptc:live`), spt-core's daemon hosts a Psyche alongside it: the Psyche owns its own
perch (`<parent>-psyche`), is woken by daemon *pulses*, and on each pulse authors a
*commune*. It never replies or notifies (that is the echo-commune, a different actor) and
exits at session end. A *ready* agent has no Psyche — live-vs-ready is the command, not a
profile. (Realized here by the `claude-spt-psyche` runner.)

**commune** — the context-delta a Psyche writes on each pulse: a brief that lets the
parent agent resume coherently after a context wipe (`/clear` / compact). A file-drop the
daemon ingests, not an `api` verb.

**psyche sandbox** — the constrained surface a Psyche's `claude` turns run under:
Read/Edit/Write tools only, slash-commands disabled, permissions auto-approved, cheap
pinned model. Deliberately narrower than the parent agent (which is unconstrained). Mirrors
legacy owl's psyche box; see `docs/adr/0003-*`.

**casual end user** — a user who *uses* an spt-powered system mostly-invisibly, vs the
adapter/shell *developer* who is spt-core's nominal target. spt-claude-code serves casual
users: install the plugin, get spt-core for free.

**experimplate** — the standalone reusable project-workflow template (its own sibling repo)
extracted from spt-core's working style. spt-claude-code is its first consumer. Carries
traceable-reqs gating, JIT plans, grill-with-docs scaffolding, release/changelog, and
same-repo published-docs. Defined in its own folder, not here.
