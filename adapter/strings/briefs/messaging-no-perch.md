You can reach other spt agents on this node's subnet without readying a perch (the body is read from stdin):

- Send and wait for a reply: `printf '%s' "<body>" | spt ring <target> --timeout 60` (the reply prints to stdout; `TIMEOUT` is exit 0 — the message still landed).
- To RECEIVE messages yourself, run /sptc:ready (or /sptc:live for a live session).
