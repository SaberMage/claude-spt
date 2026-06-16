# /sptc:subnet — operative instructions

> Delivered file-backed via the `claude-spt` adapter `[strings]`
> (`[strings.skills].subnet = { file = "skills/subnet.md" }`), resolved at injection time. The
> cplugs SKILL.md stays a thin skeleton (ADR-0001).

**Goal:** manage this machine's **subnet** membership — the private group of paired machines whose
agents can reach each other across every member node. A subnet is what makes `/sptc:send`,
`/sptc:ready`, and live agents work *cross-machine* (not just locally). Covers the three primary
user intents — **create** a new subnet, **show-code** to invite another machine, **join** an
existing one — plus the **status** view.

**Do this:**

1. If `spt` is not on `PATH`, run `/sptc:setup` first (a subnet needs the running daemon).
2. The canonical, always-current verb list is `spt subnet --help` (there is no `spt how-to subnet`
   topic — the `--help` output is the source of truth). Match the user's intent to a verb:
   - **See where I stand:** `spt subnet` (bare) or `spt subnet status` — name, paired nodes,
     endpoints. Start here when unsure.
   - **Start a new subnet** (this machine becomes the first node): `spt subnet create` — mints a
     fresh subnet and prints its joining material (a 6-digit pairing code + URI + QR).
   - **Invite another machine to mine:** `spt subnet show-code` — re-displays the current subnet's
     pairing code (+ URI + QR) to hand to the machine that will join.
   - **Pair THIS machine into an existing subnet:** `spt subnet join` — guided; needs the pairing
     code from the subnet's existing member (their `create`/`show-code` output).
3. **Pairing flow (two machines):** on machine A run `spt subnet create` (or `show-code` if it
   already has one) → read off the 6-digit code → on machine B run `spt subnet join` and supply
   that code. Confirm with `spt subnet status` on both (each should list the other as a paired node).
4. **Lifecycle verbs** (mention only if asked): `leave` (drop this node's membership),
   `detach`/`attach` (stop/resume serving a held subnet without leaving), `revoke`/`prune`
   (fleet-wide node removal + seed rotation), `notify` (subnet-wide user notification).
5. Confirm to the user what changed (subnet name, the code to share, or the newly paired node).
   Pairing codes are sensitive joining material — share them only with machines that should join.
<!-- [doc->REQ-SKILL-SUBNET] -->
