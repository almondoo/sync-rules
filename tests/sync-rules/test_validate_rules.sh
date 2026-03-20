#!/usr/bin/env bash
# Tests for validate_rules.py
# Run from repo root: bash tests/sync-rules/test_validate_rules.sh

set -euo pipefail

SCRIPT="plugins/sync-rules/skills/sync-rules/scripts/validate_rules.py"
PASS=0
FAIL=0
TMPDIR=""

setup() {
  TMPDIR=$(mktemp -d)
}

teardown() {
  [[ -n "$TMPDIR" ]] && rm -rf "$TMPDIR"
}

trap teardown EXIT

assert_pass() {
  local label="$1"
  if python3 "$SCRIPT" "$TMPDIR" > /dev/null 2>&1; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (expected pass, got fail)"
    python3 "$SCRIPT" "$TMPDIR" 2>&1 | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  fi
}

assert_fail() {
  local label="$1" expected_msg="$2"
  local out
  if out=$(python3 "$SCRIPT" "$TMPDIR" 2>&1); then
    echo "  FAIL: $label (expected fail, got pass)"
    FAIL=$((FAIL + 1))
  else
    if echo "$out" | grep -Fq "$expected_msg"; then
      echo "  PASS: $label"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: $label (expected message not found)"
      echo "    expected: $expected_msg"
      echo "    actual:"
      echo "$out" | sed 's/^/      /'
      FAIL=$((FAIL + 1))
    fi
  fi
}

# Helper: write a valid scoped rule file (with frontmatter)
write_valid_scoped() {
  local filename="$1"
  cat > "$TMPDIR/$filename" << 'RULE'
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

### Examples

```ts
// Good: use vitest
import { describe, it, expect } from 'vitest'
```

<!-- sync-rules:end:unit-tests -->
RULE
}

# Helper: write a valid code-style.md (no frontmatter)
write_valid_code_style() {
  cat > "$TMPDIR/code-style.md" << 'RULE'
<!-- generated-by: sync-rules, last-synced: 2026-03-20 -->

# Code Style

<!-- sync-rules:begin:naming -->
## Naming Conventions

- **Rule**: Use camelCase for variables and functions
  - Rationale: Project convention

<!-- sync-rules:end:naming -->
RULE
}

# ============================================================
# Valid files
# ============================================================

echo "=== Valid scoped rule file ==="
setup
write_valid_scoped "testing.md"
assert_pass "valid testing.md passes"
teardown

echo "=== Valid code-style.md (no frontmatter) ==="
setup
write_valid_code_style
assert_pass "valid code-style.md passes"
teardown

echo "=== Multiple valid files ==="
setup
write_valid_code_style
write_valid_scoped "testing.md"
write_valid_scoped "error-handling.md"
assert_pass "multiple valid files all pass"
teardown

# ============================================================
# Line count
# ============================================================

echo "=== Exceeds 200 lines ==="
setup
{
  echo '---'
  echo 'paths:'
  echo '  - "src/**/*.ts"'
  echo '---'
  echo '<!-- generated-by: sync-rules, last-synced: 2026-03-20 -->'
  echo '<!-- sync-rules:begin:filler -->'
  for i in $(seq 1 200); do echo "line $i"; done
  echo '<!-- sync-rules:end:filler -->'
} > "$TMPDIR/testing.md"
assert_fail "detects over 200 lines" "Exceeds 200-line limit"
teardown

# ============================================================
# Frontmatter checks
# ============================================================

echo "=== Missing frontmatter on non-code-style file ==="
setup
cat > "$TMPDIR/testing.md" << 'RULE'
<!-- generated-by: sync-rules, last-synced: 2026-03-20 -->

# Testing

<!-- sync-rules:begin:basics -->
## Basics
<!-- sync-rules:end:basics -->
RULE
assert_fail "detects missing frontmatter" "Missing paths: frontmatter"
teardown

echo "=== code-style.md with frontmatter ==="
setup
cat > "$TMPDIR/code-style.md" << 'RULE'
---
paths:
  - "src/**/*.ts"
---
<!-- generated-by: sync-rules, last-synced: 2026-03-20 -->

# Code Style

<!-- sync-rules:begin:naming -->
## Naming
<!-- sync-rules:end:naming -->
RULE
assert_fail "detects frontmatter on code-style.md" "code-style.md must not have frontmatter"
teardown

echo "=== Frontmatter without paths field ==="
setup
cat > "$TMPDIR/testing.md" << 'RULE'
---
description: "some rule"
---
<!-- generated-by: sync-rules, last-synced: 2026-03-20 -->

# Testing

<!-- sync-rules:begin:basics -->
## Basics
<!-- sync-rules:end:basics -->
RULE
assert_fail "detects frontmatter missing paths" "missing 'paths:' field"
teardown

echo "=== Unclosed frontmatter ==="
setup
cat > "$TMPDIR/testing.md" << 'RULE'
---
paths:
  - "src/**/*.ts"

<!-- generated-by: sync-rules, last-synced: 2026-03-20 -->
<!-- sync-rules:begin:basics -->
## Basics
<!-- sync-rules:end:basics -->
RULE
assert_fail "detects unclosed frontmatter" "Frontmatter opened but never closed"
teardown

# ============================================================
# Metadata comment
# ============================================================

echo "=== Missing metadata comment ==="
setup
cat > "$TMPDIR/testing.md" << 'RULE'
---
paths:
  - "src/**/*.ts"
---

# Testing

<!-- sync-rules:begin:basics -->
## Basics
<!-- sync-rules:end:basics -->
RULE
assert_fail "detects missing metadata comment" "Missing metadata comment"
teardown

# ============================================================
# Section markers
# ============================================================

echo "=== Unclosed section (missing end marker) ==="
setup
cat > "$TMPDIR/testing.md" << 'RULE'
---
paths:
  - "src/**/*.ts"
---
<!-- generated-by: sync-rules, last-synced: 2026-03-20 -->

# Testing

<!-- sync-rules:begin:basics -->
## Basics
RULE
assert_fail "detects unclosed section" "Unclosed section (missing end marker): basics"
teardown

echo "=== Orphaned end marker ==="
setup
cat > "$TMPDIR/testing.md" << 'RULE'
---
paths:
  - "src/**/*.ts"
---
<!-- generated-by: sync-rules, last-synced: 2026-03-20 -->

# Testing

<!-- sync-rules:end:orphan -->
RULE
assert_fail "detects orphaned end marker" "Orphaned end marker (no matching begin): orphan"
teardown

echo "=== Duplicate section ID ==="
setup
cat > "$TMPDIR/testing.md" << 'RULE'
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
assert_fail "detects duplicate section ID" "Duplicate section ID: basics"
teardown

# ============================================================
# Code fences
# ============================================================

echo "=== Unclosed code fence ==="
setup
cat > "$TMPDIR/testing.md" << 'RULE'
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
assert_fail "detects unclosed code fence" "Unclosed code fence"
teardown

# ============================================================
# CLI edge cases
# ============================================================

echo "=== No arguments ==="
if python3 "$SCRIPT" 2>/dev/null; then
  echo "  FAIL: should exit non-zero with no args"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: exits non-zero with no args"
  PASS=$((PASS + 1))
fi

echo "=== Non-existent directory ==="
if python3 "$SCRIPT" "/tmp/nonexistent_dir_$(date +%s)" 2>/dev/null; then
  echo "  FAIL: should exit non-zero for missing dir"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: exits non-zero for missing dir"
  PASS=$((PASS + 1))
fi

echo "=== Empty directory ==="
setup
if python3 "$SCRIPT" "$TMPDIR" > /dev/null 2>&1; then
  echo "  PASS: exits zero for empty dir (no files to validate)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: should exit zero for empty dir"
  FAIL=$((FAIL + 1))
fi
teardown

# ============================================================
# Summary
# ============================================================

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]]
