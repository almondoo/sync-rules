#!/usr/bin/env bash
# Consolidated test suite for sync-rules skill.
# Run from repo root: bash tests/sync-rules/test_sync_rules.sh
#
# Sections:
#   1. count_files.py unit tests (15)
#   2. validate_rules.py unit tests (16)
#   3. Eval scenario integration smoke tests (3)
#   4. Fixture output verification (go-update-mode only, others when available)

set -euo pipefail

COUNT="plugins/sync-rules/skills/sync-rules/scripts/count_files.py"
VALIDATE="plugins/sync-rules/skills/sync-rules/scripts/validate_rules.py"
EVAL_DIR="tests/sync-rules"
FIXTURES_DIR="tests/sync-rules/fixtures"
PASS=0
FAIL=0
MANUAL_ITEMS=""

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -Fq "$needle"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    echo "    expected to contain: $needle"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  if ! echo "$haystack" | grep -Fq "$needle"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    echo "    expected NOT to contain: $needle"
    FAIL=$((FAIL + 1))
  fi
}

# ============================================================
# 1. count_files.py — unit tests (15)
# ============================================================

echo "==== count_files.py ===="

echo "--- Basic counting ---"
OUT=$(printf '%s\n' 'src/app.ts' 'src/utils.ts' 'lib/helper.go' 'package.json' | python3 "$COUNT")
assert_eq "total" "4" "$(echo "$OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['total'])")"
assert_eq "src count" "2" "$(echo "$OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['dirs']['src'])")"
assert_eq "lib count" "1" "$(echo "$OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['dirs']['lib'])")"
assert_eq "root count" "1" "$(echo "$OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['dirs']['.'])")"

echo "--- Extension counting ---"
OUT=$(printf '%s\n' 'src/a.ts' 'src/b.ts' 'src/c.tsx' 'lib/d.go' | python3 "$COUNT")
assert_eq ".ts count" "2" "$(echo "$OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['extensions']['.ts'])")"
assert_eq ".tsx count" "1" "$(echo "$OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['extensions']['.tsx'])")"
assert_eq ".go count" "1" "$(echo "$OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['extensions']['.go'])")"

echo "--- Deep directory grouping ---"
OUT=$(printf '%s\n' 'src/api/v2/handlers/internal/user.ts' | python3 "$COUNT")
assert_contains "depth 4 truncation" '"src/api/v2/handlers"' "$OUT"

OUT=$(printf '%s\n' 'src/api/v2/handlers/internal/user.ts' | python3 "$COUNT" --depth 2)
assert_contains "depth 2 truncation" '"src/api"' "$OUT"

OUT=$(printf '%s\n' 'src/api/v2/handlers/internal/user.ts' | python3 "$COUNT" --depth 0)
assert_contains "depth 0 (no limit)" '"src/api/v2/handlers/internal"' "$OUT"

echo "--- --json flag ---"
OUT=$(python3 "$COUNT" --json '["src/app.ts", "lib/util.go"]')
assert_eq "json flag total" "2" "$(echo "$OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['total'])")"

echo "--- Error handling ---"
if echo -n "" | python3 "$COUNT" 2>/dev/null; then
  echo "  FAIL: should exit non-zero on empty stdin"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: exits non-zero on empty stdin"
  PASS=$((PASS + 1))
fi
if python3 "$COUNT" --json 'not-json' 2>/dev/null; then
  echo "  FAIL: should exit non-zero on invalid JSON"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: exits non-zero on invalid JSON"
  PASS=$((PASS + 1))
fi

echo "--- Output has all required keys ---"
OUT=$(printf '%s\n' 'src/app.ts' | python3 "$COUNT")
KEYS=$(echo "$OUT" | python3 -c "import sys,json; print(sorted(json.load(sys.stdin).keys()))")
assert_eq "output keys" "['dirs', 'extensions', 'total']" "$KEYS"

# ============================================================
# 2. validate_rules.py — unit tests (16)
# ============================================================

echo ""
echo "==== validate_rules.py ===="
VTMP=""

v_setup() { VTMP=$(mktemp -d); }
v_teardown() { [[ -n "$VTMP" ]] && rm -rf "$VTMP"; VTMP=""; }

v_assert_pass() {
  local label="$1"
  if python3 "$VALIDATE" "$VTMP" > /dev/null 2>&1; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (expected pass)"
    FAIL=$((FAIL + 1))
  fi
}

v_assert_fail() {
  local label="$1" expected_msg="$2" out
  if out=$(python3 "$VALIDATE" "$VTMP" 2>&1); then
    echo "  FAIL: $label (expected fail, got pass)"
    FAIL=$((FAIL + 1))
  elif echo "$out" | grep -Fq "$expected_msg"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (message not found: $expected_msg)"
    FAIL=$((FAIL + 1))
  fi
}

write_valid_scoped() {
  cat > "$VTMP/$1" << 'RULE'
---
paths:
  - "src/**/*.ts"
---
<!-- generated-by: sync-rules, last-synced: 2026-03-20 -->

# Testing

<!-- sync-rules:begin:unit-tests -->
## Unit Tests

- **Rule**: Use vitest for all unit tests
  - Rationale: Project standard

```ts
// Good: use vitest
import { describe, it, expect } from 'vitest'
```

<!-- sync-rules:end:unit-tests -->
RULE
}

write_valid_code_style() {
  cat > "$VTMP/code-style-go.md" << 'RULE'
---
paths:
  - "internal/**/*.go"
  - "pkg/**/*.go"
---
<!-- generated-by: sync-rules, last-synced: 2026-03-20 -->

# Code Style

<!-- sync-rules:begin:naming -->
## Naming Conventions

- **Rule**: Use camelCase for variables and functions
  - Rationale: Go convention

<!-- sync-rules:end:naming -->
RULE
}

echo "--- Valid files ---"
v_setup; write_valid_scoped "testing.md"
v_assert_pass "valid scoped rule file"
v_teardown

v_setup; write_valid_code_style
v_assert_pass "valid code-style-go.md (with frontmatter)"
v_teardown

v_setup; write_valid_code_style; write_valid_scoped "testing.md"; write_valid_scoped "error-handling.md"
v_assert_pass "multiple valid files (including code-style-go.md)"
v_teardown

echo "--- Line count ---"
v_setup
{ echo '---'; echo 'paths:'; echo '  - "src/**/*.ts"'; echo '---'
  echo '<!-- generated-by: sync-rules, last-synced: 2026-03-20 -->'
  echo '<!-- sync-rules:begin:filler -->'
  for i in $(seq 1 200); do echo "line $i"; done
  echo '<!-- sync-rules:end:filler -->'
} > "$VTMP/testing.md"
v_assert_fail "detects over 200 lines" "Exceeds 200-line limit"
v_teardown

echo "--- Frontmatter ---"
v_setup
cat > "$VTMP/testing.md" << 'RULE'
<!-- generated-by: sync-rules, last-synced: 2026-03-20 -->
# Testing
<!-- sync-rules:begin:basics -->
## Basics
<!-- sync-rules:end:basics -->
RULE
v_assert_fail "missing frontmatter" "Missing paths: frontmatter"
v_teardown

v_setup
cat > "$VTMP/code-style-go.md" << 'RULE'
<!-- generated-by: sync-rules, last-synced: 2026-03-20 -->
# Code Style
<!-- sync-rules:begin:naming -->
## Naming
<!-- sync-rules:end:naming -->
RULE
v_assert_fail "code-style-go.md without frontmatter" "Missing paths: frontmatter"
v_teardown

v_setup
cat > "$VTMP/testing.md" << 'RULE'
---
description: "some rule"
---
<!-- generated-by: sync-rules, last-synced: 2026-03-20 -->
# Testing
<!-- sync-rules:begin:basics -->
## Basics
<!-- sync-rules:end:basics -->
RULE
v_assert_fail "frontmatter without paths field" "missing 'paths:' field"
v_teardown

v_setup
cat > "$VTMP/testing.md" << 'RULE'
---
paths:
  - "src/**/*.ts"

<!-- generated-by: sync-rules, last-synced: 2026-03-20 -->
<!-- sync-rules:begin:basics -->
## Basics
<!-- sync-rules:end:basics -->
RULE
v_assert_fail "unclosed frontmatter" "Frontmatter opened but never closed"
v_teardown

echo "--- Metadata comment ---"
v_setup
cat > "$VTMP/testing.md" << 'RULE'
---
paths:
  - "src/**/*.ts"
---
# Testing
<!-- sync-rules:begin:basics -->
## Basics
<!-- sync-rules:end:basics -->
RULE
v_assert_fail "missing metadata comment" "Missing metadata comment"
v_teardown

echo "--- Section markers ---"
v_setup
cat > "$VTMP/testing.md" << 'RULE'
---
paths:
  - "src/**/*.ts"
---
<!-- generated-by: sync-rules, last-synced: 2026-03-20 -->
# Testing
<!-- sync-rules:begin:basics -->
## Basics
RULE
v_assert_fail "unclosed section" "Unclosed section (missing end marker): basics"
v_teardown

v_setup
cat > "$VTMP/testing.md" << 'RULE'
---
paths:
  - "src/**/*.ts"
---
<!-- generated-by: sync-rules, last-synced: 2026-03-20 -->
# Testing
<!-- sync-rules:end:orphan -->
RULE
v_assert_fail "orphaned end marker" "Orphaned end marker (no matching begin): orphan"
v_teardown

v_setup
cat > "$VTMP/testing.md" << 'RULE'
---
paths:
  - "src/**/*.ts"
---
<!-- generated-by: sync-rules, last-synced: 2026-03-20 -->
# Testing
<!-- sync-rules:begin:basics -->
## Basics
<!-- sync-rules:end:basics -->
<!-- sync-rules:begin:basics -->
## Basics Again
<!-- sync-rules:end:basics -->
RULE
v_assert_fail "duplicate section ID" "Duplicate section ID: basics"
v_teardown

echo "--- Code fences ---"
v_setup
cat > "$VTMP/testing.md" << 'RULE'
---
paths:
  - "src/**/*.ts"
---
<!-- generated-by: sync-rules, last-synced: 2026-03-20 -->
# Testing
<!-- sync-rules:begin:basics -->
## Basics

```ts
const x = 1

<!-- sync-rules:end:basics -->
RULE
v_assert_fail "unclosed code fence" "Unclosed code fence"
v_teardown

echo "--- CLI edge cases ---"
if python3 "$VALIDATE" 2>/dev/null; then
  echo "  FAIL: should exit non-zero with no args"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: exits non-zero with no args"
  PASS=$((PASS + 1))
fi

if python3 "$VALIDATE" "/tmp/nonexistent_dir_$$" 2>/dev/null; then
  echo "  FAIL: should exit non-zero for missing dir"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: exits non-zero for missing dir"
  PASS=$((PASS + 1))
fi

v_setup
if python3 "$VALIDATE" "$VTMP" > /dev/null 2>&1; then
  echo "  PASS: exits zero for empty dir"
  PASS=$((PASS + 1))
else
  echo "  FAIL: should exit zero for empty dir"
  FAIL=$((FAIL + 1))
fi
v_teardown

# ============================================================
# 3. Eval scenario — integration smoke tests (3)
#    Verifies count_files produces valid JSON with correct keys
#    for realistic file lists. Manual checklists collected.
# ============================================================

echo ""
echo "==== Eval scenarios ===="

EXPECTED_KEYS='["dirs","extensions","total"]'

for eval_file in "$EVAL_DIR"/*.json; do
  [[ -f "$eval_file" ]] || continue

  # Skip files without "files" field
  has_files=$(python3 -c "import json; d=json.load(open('$eval_file')); print('yes' if 'files' in d else 'no')")
  [[ "$has_files" == "yes" ]] || continue

  name=$(python3 -c "import json; print(json.load(open('$eval_file'))['name'])")
  files_json=$(python3 -c "import json; print(json.dumps(json.load(open('$eval_file'))['files']))")

  echo "--- $name ---"

  # Smoke test: count_files runs and returns valid JSON with all keys
  if OUT=$(python3 "$COUNT" --json "$files_json" 2>/dev/null) \
     && echo "$OUT" | python3 -c "
import sys, json
out = json.load(sys.stdin)
expected = $EXPECTED_KEYS
missing = [k for k in expected if k not in out]
if missing:
    print(f'Missing keys: {missing}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null; then
    echo "  PASS: $name — valid output with all keys"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name — invalid output or missing keys"
    FAIL=$((FAIL + 1))
  fi

  # Collect manual checklist items
  items=$(python3 -c "
import json
d = json.load(open('$eval_file'))
for b in d.get('expected_behavior', []):
    print(f'    [ ] {b}')
")
  if [[ -n "$items" ]]; then
    MANUAL_ITEMS+="  $name:
$items
"
  fi
done

# ============================================================
# 4. Fixture output verification
#    Only runs on fixtures that have .claude/rules/ (skill executed).
# ============================================================

echo ""
echo "==== Fixture verification ===="

for fixture in "$FIXTURES_DIR"/*/; do
  [[ -d "$fixture" ]] || continue
  scenario=$(basename "$fixture")
  eval_json="$EVAL_DIR/$scenario.json"
  rules_dir="$fixture/.claude/rules"

  [[ -f "$eval_json" ]] || continue
  [[ -d "$rules_dir" ]] || continue

  echo "--- $scenario ---"

  # validate_rules.py on auto-generated files only
  vtmp=$(mktemp -d)
  for f in "$rules_dir"/*.md; do
    [[ -f "$f" ]] || continue
    if grep -q "generated-by: sync-rules" "$f"; then
      cp "$f" "$vtmp/"
    fi
  done

  if [[ -n "$(ls -A "$vtmp" 2>/dev/null)" ]]; then
    if python3 "$VALIDATE" "$vtmp" > /dev/null 2>&1; then
      echo "  PASS: structural validation"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: structural validation"
      python3 "$VALIDATE" "$vtmp" 2>&1 | sed 's/^/    /'
      FAIL=$((FAIL + 1))
    fi
  fi
  rm -rf "$vtmp"

  # Verify constraints from eval JSON
  result=$(python3 - "$eval_json" "$rules_dir" << 'PYEOF'
import json, os, sys

with open(sys.argv[1]) as f:
    data = json.load(f)

verify = data.get("verify", {})
if not verify:
    print("RESULT:0:0")
    sys.exit(0)

rules_dir = sys.argv[2]
pass_count = 0
fail_count = 0
existing_files = [f for f in os.listdir(rules_dir) if f.endswith(".md")]

for f in verify.get("required_files", []):
    if f in existing_files:
        print(f"  PASS: required '{f}' exists")
        pass_count += 1
    else:
        print(f"  FAIL: required '{f}' missing")
        fail_count += 1

for f in verify.get("forbidden_files", []):
    if f not in existing_files:
        print(f"  PASS: forbidden '{f}' absent")
        pass_count += 1
    else:
        print(f"  FAIL: forbidden '{f}' should not exist")
        fail_count += 1

for filename, desc in verify.get("preserve_files", {}).items():
    filepath = os.path.join(rules_dir, filename)
    if not os.path.exists(filepath):
        print(f"  FAIL: preserved '{filename}' deleted")
        fail_count += 1
        continue
    with open(filepath) as f:
        content = f.read()
    if "generated-by: sync-rules" not in content:
        print(f"  PASS: '{filename}' preserved")
        pass_count += 1
    else:
        print(f"  FAIL: '{filename}' overwritten with metadata")
        fail_count += 1

for filename, checks in verify.get("file_checks", {}).items():
    filepath = os.path.join(rules_dir, filename)
    if not os.path.exists(filepath):
        continue
    with open(filepath) as f:
        content = f.read()
    has_fm = content.startswith("---\n")
    if "has_frontmatter" in checks:
        exp = checks["has_frontmatter"]
        if has_fm == exp:
            label = "has" if exp else "no"
            print(f"  PASS: {filename} — {label} frontmatter")
            pass_count += 1
        else:
            print(f"  FAIL: {filename} — wrong frontmatter state")
            fail_count += 1
    fm = ""
    if has_fm:
        idx = content.find("\n---\n", 4)
        if idx != -1:
            fm = content[4:idx]
    for n in checks.get("frontmatter_contains", []):
        if n in fm:
            print(f"  PASS: {filename} frontmatter contains '{n}'")
            pass_count += 1
        else:
            print(f"  FAIL: {filename} frontmatter missing '{n}'")
            fail_count += 1
    for n in checks.get("frontmatter_not_contains", []):
        if n not in fm:
            print(f"  PASS: {filename} frontmatter excludes '{n}'")
            pass_count += 1
        else:
            print(f"  FAIL: {filename} frontmatter has '{n}'")
            fail_count += 1
    for n in checks.get("content_contains", []):
        if n in content:
            print(f"  PASS: {filename} contains '{n}'")
            pass_count += 1
        else:
            print(f"  FAIL: {filename} missing '{n}'")
            fail_count += 1
    for n in checks.get("content_not_contains", []):
        if n not in content:
            print(f"  PASS: {filename} excludes '{n}'")
            pass_count += 1
        else:
            print(f"  FAIL: {filename} has '{n}'")
            fail_count += 1

print(f"RESULT:{pass_count}:{fail_count}")
PYEOF
  )

  echo "$result" | grep -v "^RESULT:"
  counts=$(echo "$result" | grep "^RESULT:" | tail -1)
  if [[ -n "$counts" ]]; then
    PASS=$((PASS + $(echo "$counts" | cut -d: -f2)))
    FAIL=$((FAIL + $(echo "$counts" | cut -d: -f3)))
  fi
done

# ============================================================
# Summary
# ============================================================

echo ""
echo "========================================"
echo "=== Total: $PASS passed, $FAIL failed ==="
echo "========================================"

if [[ -n "$MANUAL_ITEMS" ]]; then
  echo ""
  echo "Manual verification checklist:"
  echo "$MANUAL_ITEMS"
fi

[[ $FAIL -eq 0 ]]
