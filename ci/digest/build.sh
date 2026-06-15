#!/bin/sh
# Build + unit-test the claude-spt-digest extractor crate (Rust). The crate's cargo tests ARE the
# extractor's unit coverage (CC-JSONL -> digest-NDJSON mapping, drop cases, UTF-8, contract
# invariants). SKIP if cargo is absent so a host without the Rust toolchain announces it rather than
# silently passing (no silent caps). [impl->REQ-DIST-DIGEST-EXTRACTOR]
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
CRATE="$ROOT/tools/claude-spt-digest/Cargo.toml"

if ! command -v cargo >/dev/null 2>&1; then
  echo "SKIP: cargo not on PATH (Rust toolchain needed to build/test claude-spt-digest)"
  exit 0
fi

cargo test  --quiet --manifest-path "$CRATE" || { echo "FAIL: cargo test"; exit 1; }
cargo build --release --quiet --manifest-path "$CRATE" || { echo "FAIL: cargo build --release"; exit 1; }
echo "ok  claude-spt-digest: cargo test + release build"
