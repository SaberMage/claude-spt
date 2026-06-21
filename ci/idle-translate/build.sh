#!/bin/sh
# Build + unit-test the cc-spt-idle-translate crate (Rust) — the [message-idle-translation-binary]
# for the claude-spt adapter. The crate's cargo tests ARE the binary's unit coverage (the 5-step
# keystroke choreography, the trailing-\r submit, CR/LF neutralization, init/input/unknown-type
# no-output, forward-compat unknown fields, single-field command shape). SKIP if cargo is absent so a
# host without the Rust toolchain announces it rather than silently passing (no silent caps).
# [impl->REQ-DIST-IDLE-TRANSLATE]
set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
CRATE="$ROOT/tools/cc-spt-idle-translate/Cargo.toml"

if ! command -v cargo >/dev/null 2>&1; then
  echo "SKIP: cargo not on PATH (Rust toolchain needed to build/test cc-spt-idle-translate)"
  exit 0
fi

cargo test  --quiet --manifest-path "$CRATE" || { echo "FAIL: cargo test"; exit 1; }
cargo build --release --quiet --manifest-path "$CRATE" || { echo "FAIL: cargo build --release"; exit 1; }
echo "ok  cc-spt-idle-translate: cargo test + release build"
