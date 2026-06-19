# /sptc:subnet — operative instructions

Manage this machine's **subnet** — the private group of paired machines whose agents reach each other
across nodes. Cross-machine `/sptc:send` and live agents depend on it.

Match the user's intent to a verb (full guidance: `spt how-to subnet`, or `spt subnet --help`):

- **Where I stand:** `spt subnet status` (or bare `spt subnet`).
- **Start a new subnet** (this machine = first node): `spt subnet create` — prints the 6-digit code
  + URI + QR.
- **Invite a machine:** `spt subnet show-code` — re-displays the current code.
- **Join an existing one:** `spt subnet join` — needs the code from a current member.

Pairing: on A run `create` (or `show-code`) → read the code → on B run `join` with it → `spt subnet
status` on both to confirm. Pairing codes are sensitive — share only with machines that should join.
<!-- [doc->REQ-SKILL-SUBNET] -->
