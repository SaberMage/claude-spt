#!/bin/sh
# The psyche runner is now the `psyche` subcommand of the CONSOLIDATED claude-spt crate (ADR-0006,
# U2) — built + unit-tested by ci/digest/build.sh (the canonical build of the one binary; its cargo
# run covers the psyche arg/command-construction tests too). This gate is kept as a thin shim so the
# run-gates "psyche-runner" slot stays meaningful and announced, WITHOUT a redundant second cargo
# build/test of the same crate ("one build", U2). The runner's resident pulse loop + subprocess spawn
# remain integration (deferred behind the daemon Psyche loop + a real live CC session, REQ-SKILL-LIVE).
# [impl->REQ-SKILL-LIVE]
# [impl->REQ-DIST-BINARY-CONSOLIDATE]
set -u
echo "ok  claude-spt-psyche: folded into the consolidated claude-spt crate (built/tested by ci/digest/build.sh)"
