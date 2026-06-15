#!/bin/sh
# Unit tests for the manifest-schema validator: it must PASS the real claude-spt manifest and FAIL
# on tampered copies (missing required field / bad enum / wrong type) — proving the gate catches
# real breakage, not just green-on-green. Run: sh tests/manifest-schema.sh  (exit 0 = pass).
# [unit->REQ-DIST-MANIFEST-SCHEMA]
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
SCHEMA="$ROOT/adapter/manifest.schema.json"
MANIFEST="$ROOT/adapter/claude-spt.toml"
VALIDATOR="$ROOT/ci/manifest/validate_manifest.py"

# Same interpreter probe as the gate wrapper — needs (tomllib|tomli)+jsonschema.
PY=""
for cand in python python3 py; do
  command -v "$cand" >/dev/null 2>&1 || continue
  if "$cand" - <<'PROBE' >/dev/null 2>&1
import importlib.util as u, sys
sys.exit(0 if ((u.find_spec("tomllib") or u.find_spec("tomli")) and u.find_spec("jsonschema")) else 1)
PROBE
  then PY="$cand"; break; fi
done
if [ -z "$PY" ]; then echo "SKIP: no python with (tomllib|tomli)+jsonschema"; echo "MANIFEST-SCHEMA OK (skipped)"; exit 0; fi

fail=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }

# 1. The real manifest validates (exit 0).
if "$PY" "$VALIDATOR" "$SCHEMA" "$MANIFEST" >/dev/null 2>&1; then ok "real manifest validates"; else bad "real manifest rejected"; "$PY" "$VALIDATOR" "$SCHEMA" "$MANIFEST"; fi

work=$(mktemp -d) || { echo "FAIL mktemp"; exit 1; }
trap 'rm -rf "$work"' EXIT INT TERM

# helper: write a manifest body to a temp file, expect validator to REJECT it (exit non-zero).
expect_reject() {
  desc=$1; file="$work/m.toml"
  if "$PY" "$VALIDATOR" "$SCHEMA" "$file" >/dev/null 2>&1; then bad "$desc not caught"; else ok "catches $desc"; fi
}

# 2. Missing the required [adapter] table entirely.
cat > "$work/m.toml" <<'EOF'
[strings]
adapter_label = "x"
EOF
expect_reject "missing [adapter]"

# 3. [adapter] missing a required field (min_spt_core_version).
cat > "$work/m.toml" <<'EOF'
[adapter]
name = "claude-spt"
version = "0.1.0"
EOF
expect_reject "missing required adapter.min_spt_core_version"

# 4. Bad enum value for adapter.kind.
cat > "$work/m.toml" <<'EOF'
[adapter]
name = "claude-spt"
kind = "robot"
version = "0.1.0"
min_spt_core_version = "0.7.0"
EOF
expect_reject "invalid adapter.kind enum"

# 5. Wrong type: a hook with no `fires` (required) / wrong shape.
cat > "$work/m.toml" <<'EOF'
[adapter]
name = "claude-spt"
version = "0.1.0"
min_spt_core_version = "0.7.0"
[hooks.SessionStart]
reads = ["session_id"]
EOF
expect_reject "hook missing required fires"

# 6. Wrong type: shortcut_basename as an integer.
cat > "$work/m.toml" <<'EOF'
[adapter]
name = "claude-spt"
version = "0.1.0"
min_spt_core_version = "0.7.0"
shortcut_basename = 42
EOF
expect_reject "non-string shortcut_basename"

[ "$fail" -eq 0 ] && { echo "MANIFEST-SCHEMA OK"; exit 0; } || { echo "MANIFEST-SCHEMA FAIL"; exit 1; }
