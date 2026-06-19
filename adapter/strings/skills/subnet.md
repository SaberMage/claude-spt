# /sptc:subnet — operative instructions

**Goal:** manage this machine's **subnet** membership — the private group of paired machines whose
agents reach each other across nodes. Cross-machine `/sptc:send`, `/sptc:ready`, and live agents
depend on it.

**Do this:**

1. If `spt` is not on `PATH`, run `/sptc:setup` first (a subnet needs the running daemon).
2. The canonical, always-current verb list is `spt subnet --help`. Match the user's intent:
   - **Where I stand:** `spt subnet` (bare) or `spt subnet status` — name, paired nodes, endpoints.
     Start here when unsure.
   - **Start a new subnet** (this machine = first node): `spt subnet create` — mints it and prints
     the joining material (6-digit pairing code + URI + QR).
   - **Invite another machine:** `spt subnet show-code` — re-displays the current code (+ URI + QR).
   - **Pair THIS machine into an existing subnet:** `spt subnet join` — needs the code from an
     existing member.
3. **Pairing (two machines):** on A run `create` (or `show-code`) → read the 6-digit code → on B run
   `join` and supply it → confirm with `spt subnet status` on both (each lists the other).
4. **Lifecycle verbs (only if asked):** `leave`, `detach`/`attach`, `revoke`/`prune`, `notify`.
5. Confirm what changed. Pairing codes are sensitive joining material — share them only with machines
   that should join.
<!-- [doc->REQ-SKILL-SUBNET] -->
