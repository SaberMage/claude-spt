# /sptc:ready — operative instructions

Make this session reachable for inter-agent messages. Fewest steps — the user is waiting on bringup.

1. Pick the id: the one the user gave, else `spt whoami`. Call it `<id>`.
2. Run the listener as a single PERSISTENT background task via the **Monitor** tool:
   - `command: "spt ready <id>"`
   - `persistent: true`
   - `description: "« spt event »"`

   It blocks for the session's life, emitting one `<EVENT type="msg" from="<sender>">body</EVENT>` per
   delivery. Announce reachable — don't wait on markers.
3. To reply, pipe the message body to `spt send <sender>` (sender = the `from` on the EVENT).

Full guidance: `spt how-to ready`. (No long-running tasks available? `spt ready <id> --once` drains the
backlog, waits for one delivery, then exits — re-run to stay reachable.)
