#!/usr/bin/env bash
# Verify sync-rules skill output against fixture project constraints.
# Run AFTER executing the sync-rules skill on fixture(s).
#
# Usage:
#   bash tests/sync-rules/verify_skill_output.sh                              # all fixtures
#   bash tests/sync-rules/verify_skill_output.sh tests/sync-rules/fixtures/typescript-react  # single
#
# Flow per fixture:
#   1. Run validate_rules.py on auto-generated files in .claude/rules/
#   2. Check verify constraints from the matching eval JSON
#   3. Report pass/fail

set -euo pipefail

VALIDATE="plugins/sync-rules/skills/sync-rules/scripts/validate_rules.py"
EVAL_DIR="tests/sync-rules"
FIXTURES_DIR="tests/sync-rules/fixtures"
TOTAL_PASS=0
TOTAL_FAIL=0

verify_fixture() {
  local fixture_dir="$1"
  local rules_dir="$fixture_dir/.claude/rules"
  local scenario
  scenario=$(basename "$fixture_dir")
  local eval_json="$EVAL_DIR/$scenario.json"
  local pass=0
  local fail=0

  echo "=== $scenario ==="

  if [[ ! -f "$eval_json" ]]; then
    echo "  PASS: no eval JSON (nothing to verify)"
    TOTAL_PASS=$((TOTAL_PASS + 1))
    echo ""
    return
  fi

  if [[ ! -d "$rules_dir" ]]; then
    echo "  PASS: no .claude/rules/ yet (skill not executed)"
    TOTAL_PASS=$((TOTAL_PASS + 1))
    echo ""
    return
  fi

  # Step 1: validate_rules.py (only on auto-generated files)
  local vtmp
  vtmp=$(mktemp -d)

  for f in "$rules_dir"/*.md; do
    [[ -f "$f" ]] || continue
    if grep -q "generated-by: sync-rules" "$f"; then
      cp "$f" "$vtmp/"
    fi
  done

  if [[ -z "$(ls -A "$vtmp" 2>/dev/null)" ]]; then
    echo "  SKIP: No auto-generated rule files to validate"
  else
    if python3 "$VALIDATE" "$vtmp" 2>&1 | sed 's/^/  /'; then
      echo "  PASS: structural validation"
      pass=$((pass + 1))
    else
      echo "  FAIL: structural validation"
      fail=$((fail + 1))
    fi
  fi
  rm -rf "$vtmp"

  # Step 2: verify constraints from eval JSON
  local result
  result=$(python3 - "$eval_json" "$rules_dir" << 'PYEOF'
import json, os, sys

eval_path = sys.argv[1]
rules_dir = sys.argv[2]

with open(eval_path) as f:
    data = json.load(f)

verify = data.get("verify", {})
if not verify:
    print("RESULT:0:0")
    sys.exit(0)

pass_count = 0
fail_count = 0

existing_files = [f for f in os.listdir(rules_dir) if f.endswith(".md")]

for f in verify.get("required_files", []):
    if f in existing_files:
        print(f"  PASS: required file '{f}' exists")
        pass_count += 1
    else:
        print(f"  FAIL: required file '{f}' missing")
        fail_count += 1

for f in verify.get("forbidden_files", []):
    if f not in existing_files:
        print(f"  PASS: forbidden file '{f}' absent")
        pass_count += 1
    else:
        print(f"  FAIL: forbidden file '{f}' should not exist")
        fail_count += 1

for filename, description in verify.get("preserve_files", {}).items():
    filepath = os.path.join(rules_dir, filename)
    if not os.path.exists(filepath):
        print(f"  FAIL: preserved file '{filename}' was deleted")
        fail_count += 1
        continue
    with open(filepath) as f:
        content = f.read()
    if "generated-by: sync-rules" not in content:
        print(f"  PASS: '{filename}' preserved (no sync-rules metadata)")
        pass_count += 1
    else:
        print(f"  FAIL: '{filename}' overwritten with sync-rules metadata")
        fail_count += 1

for filename, checks in verify.get("file_checks", {}).items():
    filepath = os.path.join(rules_dir, filename)
    if not os.path.exists(filepath):
        print(f"  SKIP: '{filename}' not generated (optional)")
        continue

    with open(filepath) as f:
        content = f.read()

    has_frontmatter = content.startswith("---\n")

    if "has_frontmatter" in checks:
        expected = checks["has_frontmatter"]
        label = "has" if expected else "no"
        if has_frontmatter == expected:
            print(f"  PASS: {filename} — {label} frontmatter")
            pass_count += 1
        else:
            actual_label = "has" if has_frontmatter else "no"
            print(f"  FAIL: {filename} — expected {label}, got {actual_label} frontmatter")
            fail_count += 1

    fm_content = ""
    if has_frontmatter:
        end_idx = content.find("\n---\n", 4)
        if end_idx != -1:
            fm_content = content[4:end_idx]

    for needle in checks.get("frontmatter_contains", []):
        if needle in fm_content:
            print(f"  PASS: {filename} frontmatter contains '{needle}'")
            pass_count += 1
        else:
            print(f"  FAIL: {filename} frontmatter missing '{needle}'")
            fail_count += 1

    for needle in checks.get("frontmatter_not_contains", []):
        if needle not in fm_content:
            print(f"  PASS: {filename} frontmatter excludes '{needle}'")
            pass_count += 1
        else:
            print(f"  FAIL: {filename} frontmatter should not contain '{needle}'")
            fail_count += 1

    for needle in checks.get("content_contains", []):
        if needle in content:
            print(f"  PASS: {filename} contains '{needle}'")
            pass_count += 1
        else:
            print(f"  FAIL: {filename} missing '{needle}'")
            fail_count += 1

    for needle in checks.get("content_not_contains", []):
        if needle not in content:
            print(f"  PASS: {filename} excludes '{needle}'")
            pass_count += 1
        else:
            print(f"  FAIL: {filename} should not contain '{needle}'")
            fail_count += 1

print(f"RESULT:{pass_count}:{fail_count}")
PYEOF
  )

  echo "$result" | grep -v "^RESULT:"

  local counts p f
  counts=$(echo "$result" | grep "^RESULT:" | tail -1)
  if [[ -n "$counts" ]]; then
    p=$(echo "$counts" | cut -d: -f2)
    f=$(echo "$counts" | cut -d: -f3)
    pass=$((pass + p))
    fail=$((fail + f))
  fi

  TOTAL_PASS=$((TOTAL_PASS + pass))
  TOTAL_FAIL=$((TOTAL_FAIL + fail))

  if [[ $fail -eq 0 && $pass -gt 0 ]]; then
    echo "  --- $pass passed"
  else
    echo "  --- $pass passed, $fail failed"
  fi
  echo ""
}

# Main: single fixture or all fixtures
if [[ $# -ge 1 ]]; then
  verify_fixture "$1"
else
  for fixture in "$FIXTURES_DIR"/*/; do
    [[ -d "$fixture" ]] || continue
    verify_fixture "$fixture"
  done
fi

echo "=== Total: $TOTAL_PASS passed, $TOTAL_FAIL failed ==="
[[ $TOTAL_FAIL -eq 0 ]]
