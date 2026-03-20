#!/usr/bin/env bash
# Tests for summarize_structure.py
# Run from repo root: bash tests/sync-rules/test_summarize_structure.sh

set -euo pipefail

SCRIPT="plugins/sync-rules/skills/sync-rules/scripts/summarize_structure.py"
PASS=0
FAIL=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"
    ((PASS++))
  else
    echo "  FAIL: $label"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    ((FAIL++))
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -q "$needle"; then
    echo "  PASS: $label"
    ((PASS++))
  else
    echo "  FAIL: $label"
    echo "    expected to contain: $needle"
    echo "    actual: $haystack"
    ((FAIL++))
  fi
}

assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  if ! echo "$haystack" | grep -q "$needle"; then
    echo "  PASS: $label"
    ((PASS++))
  else
    echo "  FAIL: $label"
    echo "    expected NOT to contain: $needle"
    echo "    actual: $haystack"
    ((FAIL++))
  fi
}

# --- Mixed file types ---
echo "=== Mixed file types ==="
OUT=$(printf '%s\n' \
  'src/app.ts' \
  'src/app.test.ts' \
  'package.json' \
  'tsconfig.json' \
  | python3 "$SCRIPT")

assert_eq "total_source_files" "1" "$(echo "$OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['total_source_files'])")"
assert_eq "total_test_files" "1" "$(echo "$OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['total_test_files'])")"
assert_contains "config has package.json" "package.json" "$OUT"
assert_contains "config has tsconfig.json" "tsconfig.json" "$OUT"
assert_contains "extensions has .ts" '".ts"' "$OUT"

# --- Config detection (exact + prefix) ---
echo "=== Config detection ==="
OUT=$(printf '%s\n' \
  'package.json' \
  '.eslintrc.js' \
  '.prettierrc.yaml' \
  '.golangci.yml' \
  'eslint.config.mjs' \
  'biome.json' \
  | python3 "$SCRIPT")

assert_eq "configs not counted as source" "0" "$(echo "$OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['total_source_files'])")"
assert_contains "detects package.json" "package.json" "$OUT"
assert_contains "detects .eslintrc.js" ".eslintrc.js" "$OUT"
assert_contains "detects biome.json" "biome.json" "$OUT"

# --- Test file detection ---
echo "=== Test file detection ==="
OUT=$(printf '%s\n' \
  'src/app.test.ts' \
  'src/user.spec.tsx' \
  'internal/handler_test.go' \
  'tests/test_main.py' \
  '__tests__/App.test.tsx' \
  | python3 "$SCRIPT")

assert_eq "total_test_files" "5" "$(echo "$OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['total_test_files'])")"
assert_eq "total_source_files" "0" "$(echo "$OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['total_source_files'])")"
assert_contains "pattern *.test.ts" "*.test.ts" "$OUT"
assert_contains "pattern *.spec.tsx" "*.spec.tsx" "$OUT"
assert_contains "pattern *_test.go" "*_test.go" "$OUT"
assert_contains "pattern test_*.py" "test_*.py" "$OUT"

# --- Source dir depth-2 truncation ---
echo "=== Source dir depth-2 truncation ==="
OUT=$(printf '%s\n' \
  'src/components/Button/index.tsx' \
  'src/api/users.ts' \
  'main.go' \
  | python3 "$SCRIPT")

assert_contains "src/components grouped" '"src/components"' "$OUT"
assert_contains "src/api grouped" '"src/api"' "$OUT"
assert_contains "root file as dot" '"."' "$OUT"

# --- Unsupported extensions ignored ---
echo "=== Unsupported extensions ignored ==="
OUT=$(printf '%s\n' \
  'README.md' \
  'Dockerfile' \
  'src/app.ts' \
  | python3 "$SCRIPT")

assert_eq "only 1 source file" "1" "$(echo "$OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['total_source_files'])")"
assert_not_contains "no .md extension" '".md"' "$OUT"

# --- Extension counting ---
echo "=== Extension counting ==="
OUT=$(printf '%s\n' \
  'src/a.ts' \
  'src/b.ts' \
  'src/c.tsx' \
  | python3 "$SCRIPT")

assert_eq ".ts count" "2" "$(echo "$OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['extensions']['.ts'])")"
assert_eq ".tsx count" "1" "$(echo "$OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['extensions']['.tsx'])")"

# --- --json flag ---
echo "=== --json flag ==="
OUT=$(python3 "$SCRIPT" --json '["src/app.ts", "package.json"]')

assert_eq "json flag source count" "1" "$(echo "$OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['total_source_files'])")"
assert_contains "json flag config" "package.json" "$OUT"

# --- Error: empty stdin ---
echo "=== Error handling: empty stdin ==="
if echo -n "" | python3 "$SCRIPT" 2>/dev/null; then
  echo "  FAIL: should exit non-zero on empty stdin"
  ((FAIL++))
else
  echo "  PASS: exits non-zero on empty stdin"
  ((PASS++))
fi

# --- Error: invalid JSON ---
echo "=== Error handling: invalid JSON ==="
if python3 "$SCRIPT" --json 'not-json' 2>/dev/null; then
  echo "  FAIL: should exit non-zero on invalid JSON"
  ((FAIL++))
else
  echo "  PASS: exits non-zero on invalid JSON"
  ((PASS++))
fi

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]]
