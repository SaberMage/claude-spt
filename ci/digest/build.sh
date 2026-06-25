#!/bin/sh
# Build + unit-test the CONSOLIDATED claude-spt tool crate (Rust) — the single binary carrying the
# `digest` / `psyche` / `post-update` subcommands (ADR-0006, U2; was three crates). The crate's cargo
# tests ARE the unit coverage for all three: the digest CC-JSONL->NDJSON mapping (drop cases, UTF-8,
# contract invariants), the psyche arg/command construction, the post-update CLI detection + plugin/
# marketplace reconciliation, and the subcommand dispatch. This is the canonical build of the binary;
# ci/psyche/build.sh defers to it (no redundant cargo run). SKIP if cargo is absent so a host without
# the Rust toolchain announces it rather than silently passing (no silent caps).
# [impl->REQ-DIST-BINARY-CONSOLIDATE]
# [impl->REQ-DIST-DIGEST-EXTRACTOR]
# [impl->REQ-SKILL-LIVE]
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
CRATE="$ROOT/tools/claude-spt/Cargo.toml"

if ! command -v cargo >/dev/null 2>&1; then
  echo "SKIP: cargo not on PATH (Rust toolchain needed to build/test claude-spt)"
  exit 0
fi

cargo test  --quiet --manifest-path "$CRATE" || { echo "FAIL: cargo test"; exit 1; }
cargo build --release --quiet --manifest-path "$CRATE" || { echo "FAIL: cargo build --release"; exit 1; }
echo "ok  claude-spt: cargo test + release build (digest/psyche/post-update subcommands)"
