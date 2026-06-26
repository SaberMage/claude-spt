#!/bin/sh
# The idle-translation filter is now the `translate` subcommand of the CONSOLIDATED claude-spt crate
# (D3 fold, ADR-0006 — spt-core v0.16.0 gave [message-idle-translation-binary] a `command` field, so
# the standalone cc-spt-idle-translate crate is retired). It is built + unit-tested by ci/digest/build.sh
# (the canonical build of the one binary; its cargo run covers the translate choreography/checkpoint
# tests too). This gate is a thin shim so the run-gates "idle-translate" slot stays announced WITHOUT a
# redundant second cargo build/test of the same crate. The daemon spawn-on-up/reap-on-down lifecycle +
# atomic PTY apply stay covered by ci/idle-translate/translate-proof-int.sh (the int).
# [impl->REQ-DIST-IDLE-TRANSLATE]
set -u
echo "ok  cc-spt-idle-translate: folded into the consolidated claude-spt crate as the translate subcommand (built/tested by ci/digest/build.sh)"
