Reach another agent (the body is read from stdin):

- Send: `printf '%s' "<body>" | spt send <target>`. `SENT` = delivered live; `QUEUED` = target offline, spooled for its next listen — QUEUED is success, do not retry.
- Reply: `printf '%s' "<body>" | spt send <sender>` (sender = the `from` on the EVENT you received).
