#!/usr/bin/env bash
# Verify sync-rules skill output against fixture project constraints.
# Run AFTER executing the sync-rules skill on a fixture.
#
# Usage:
#   bash tests/sync-rules/verify_skill_output.sh <fixture_directory>
#   bash tests/sync-rules/verify_skill_output.sh tests/sync-rules/fixtures/typescript-react
#
# Flow:
#   1. Run validate_rules.py on .claude/rules/
#   2. Check verify constraints from the matching eval JSON
#   3. Report pass/fail

set -euo pipefail

VALIDATE="plugins/sync-rules/skills/sync-rules/scripts/validate_rules.py"
EVAL_DIR="tests/sync-rules"
PASS=0
FAIL=0

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <fixture_directory>" >&2
  exit 1
fi

FIXTURE_DIR="$1"
RULES_DIR="$FIXTURE_DIR/.claude/rules"
SCENARIO=$(basename "$FIXTURE_DIR")
EVAL_JSON="$EVAL_DIR/$SCENARIO.json"

if [[ ! -d "$FIXTURE_DIR" ]]; then
  echo "Error: Fixture directory '$FIXTURE_DIR' not found" >&2
  exit 1
fi

if [[ ! -f "$EVAL_JSON" ]]; then
  echo "Error: Eval JSON '$EVAL_JSON' not found" >&2
  exit 1
fi

if [[ ! -d "$RULES_DIR" ]]; then
  echo "Error: No .claude/rules/ directory in '$FIXTURE_DIR'." >&2
  echo "Run the sync-rules skill on this fixture first." >&2
  exit 1
fi

# Step 1: validate_rules.py (only on auto-generated files)
echo "=== validate_rules.py ==="
VTMP=$(mktemp -d)
trap 'rm -rf "$VTMP"' EXIT

# Copy only files containing sync-rules metadata to temp dir for validation
for f in "$RULES_DIR"/*.md; do
  [[ -f "$f" ]] || continue
  if grep -q "generated-by: sync-rules" "$f"; then
    cp "$f" "$VTMP/"
  fi
done

if [[ -z "$(ls -A "$VTMP" 2>/dev/null)" ]]; then
  echo "  SKIP: No auto-generated rule files found to validate"
else
  if python3 "$VALIDATE" "$VTMP" 2>&1 | sed 's/^/  /'; then
    echo "  PASS: All auto-generated files pass structural validation"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Structural validation errors found"
    FAIL=$((FAIL + 1))
  fi
fi

# Step 2: verify constraints from eval JSON
echo ""
echo "=== Verify constraints ($SCENARIO) ==="

result=$(python3 - "$EVAL_JSON" "$RULES_DIR" << 'PYEOF'
import json, os, sys

eval_path = sys.argv[1]
rules_dir = sys.argv[2]

with open(eval_path) as f:
    data = json.load(f)

verify = data.get("verify", {})
if not verify:
    print("  No verify constraints defined")
    print("RESULT:0:0")
    sys.exit(0)

pass_count = 0
fail_count = 0

existing_files = [f for f in os.listdir(rules_dir) if f.endswith(".md")]

# Required files
for f in verify.get("required_files", []):
    if f in existing_files:
        print(f"  PASS: required file '{f}' exists")
        pass_count += 1
    else:
        print(f"  FAIL: required file '{f}' missing")
        fail_count += 1

# Forbidden files
for f in verify.get("forbidden_files", []):
    if f not in existing_files:
        print(f"  PASS: forbidden file '{f}' absent")
        pass_count += 1
    else:
        print(f"  FAIL: forbidden file '{f}' should not exist")
        fail_count += 1

# Preserve checks (update mode: user files must not gain sync-rules metadata)
for filename, description in verify.get("preserve_files", {}).items():
    filepath = os.path.join(rules_dir, filename)
    if not os.path.exists(filepath):
        print(f"  FAIL: preserved file '{filename}' was deleted")
        fail_count += 1
        continue
    with open(filepath) as f:
        content = f.read()
    if "generated-by: sync-rules" not in content:
        print(f"  PASS: '{filename}' preserved (no sync-rules metadata injected)")
        pass_count += 1
    else:
        print(f"  FAIL: '{filename}' was overwritten with sync-rules metadata")
        fail_count += 1

# File-specific checks
for filename, checks in verify.get("file_checks", {}).items():
    filepath = os.path.join(rules_dir, filename)
    if not os.path.exists(filepath):
        print(f"  SKIP: '{filename}' not generated (optional)")
        continue

    with open(filepath) as f:
        content = f.read()

    has_frontmatter = content.startswith("---\n")

    # Frontmatter presence
    if "has_frontmatter" in checks:
        expected = checks["has_frontmatter"]
        label = "has" if expected else "no"
        if has_frontmatter == expected:
            print(f"  PASS: {filename} — {label} frontmatter")
            pass_count += 1
        else:
            actual_label = "has" if has_frontmatter else "no"
            print(f"  FAIL: {filename} — expected {label} frontmatter, got {actual_label}")
            fail_count += 1

    # Extract frontmatter content
    fm_content = ""
    if has_frontmatter:
        end_idx = content.find("\n---\n", 4)
        if end_idx != -1:
            fm_content = content[4:end_idx]

    # Frontmatter contains
    for needle in checks.get("frontmatter_contains", []):
        if needle in fm_content:
            print(f"  PASS: {filename} frontmatter contains '{needle}'")
            pass_count += 1
        else:
            print(f"  FAIL: {filename} frontmatter missing '{needle}'")
            fail_count += 1

    # Frontmatter not contains
    for needle in checks.get("frontmatter_not_contains", []):
        if needle not in fm_content:
            print(f"  PASS: {filename} frontmatter excludes '{needle}'")
            pass_count += 1
        else:
            print(f"  FAIL: {filename} frontmatter should not contain '{needle}'")
            fail_count += 1

    # Content contains
    for needle in checks.get("content_contains", []):
        if needle in content:
            print(f"  PASS: {filename} contains '{needle}'")
            pass_count += 1
        else:
            print(f"  FAIL: {filename} missing '{needle}'")
            fail_count += 1

    # Content not contains
    for needle in checks.get("content_not_contains", []):
        if needle not in content:
            print(f"  PASS: {filename} excludes '{needle}'")
            pass_count += 1
        else:
            print(f"  FAIL: {filename} should not contain '{needle}'")
            fail_count += 1

print(f"\nRESULT:{pass_count}:{fail_count}")
PYEOF
)

echo "$result" | grep -v "^RESULT:"

counts=$(echo "$result" | grep "^RESULT:" | tail -1)
if [[ -n "$counts" ]]; then
  p=$(echo "$counts" | cut -d: -f2)
  f=$(echo "$counts" | cut -d: -f3)
  PASS=$((PASS + p))
  FAIL=$((FAIL + f))
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]]
