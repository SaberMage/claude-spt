#!/bin/sh
# Build + unit-test the claude-spt-psyche runner crate (Rust). The crate's cargo tests ARE the
# runner's unit coverage (arg parse, seed/pulse/poll command construction, blank-pulse guard); the
# resident pulse loop + subprocess spawn are integration (deferred behind the daemon Psyche loop +
# a real live CC session — see REQ-SKILL-LIVE). SKIP if cargo is absent so a host without the Rust
# toolchain announces it rather than silently passing (no silent caps). [impl->REQ-SKILL-LIVE]
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
CRATE="$ROOT/tools/claude-spt-psyche/Cargo.toml"

if ! command -v cargo >/dev/null 2>&1; then
  echo "SKIP: cargo not on PATH (Rust toolchain needed to build/test claude-spt-psyche)"
  exit 0
fi

cargo test  --quiet --manifest-path "$CRATE" || { echo "FAIL: cargo test"; exit 1; }
cargo build --release --quiet --manifest-path "$CRATE" || { echo "FAIL: cargo build --release"; exit 1; }
echo "ok  claude-spt-psyche: cargo test + release build"
