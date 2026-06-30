Reach another agent (the body is read from stdin):

- Send: `printf '%s' "<body>" | spt send <target>`. `SENT` = delivered live; `QUEUED` = target offline, spooled for its next listen — QUEUED is success, do not retry.
- Reply: `printf '%s' "<body>" | spt send <sender>` (sender = the `from` on the EVENT you received).
- After you send, just continue. The reply (if any) arrives the SAME way every inbound message reaches you — through the delivery channel you already have (your existing live relay if you are a live agent, or the broker if this session is spt-hosted, or your next turn's inbound drain). You do NOT need to set up anything NEW: do not arm an EXTRA Monitor/poll/tail just to wait for this one reply (and do not tear down the relay you are already running).
