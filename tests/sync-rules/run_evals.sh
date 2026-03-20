#!/usr/bin/env bash
# Eval runner for sync-rules skill scenarios.
# Feeds each scenario's file list to summarize_structure.py and checks assertions.
# Expected behaviors that require full skill execution are printed as a manual checklist.
#
# Run from repo root: bash tests/sync-rules/run_evals.sh

set -euo pipefail

SUMMARIZE="plugins/sync-rules/skills/sync-rules/scripts/summarize_structure.py"
EVAL_DIR="tests/sync-rules"
TOTAL_PASS=0
TOTAL_FAIL=0

for eval_file in "$EVAL_DIR"/*.json; do
  # Run assertions via embedded Python
  result=$(python3 - "$eval_file" "$SUMMARIZE" << 'PYEOF'
import json, subprocess, sys

eval_path = sys.argv[1]
script_path = sys.argv[2]

with open(eval_path) as f:
    data = json.load(f)

if "files" not in data or "assertions" not in data:
    sys.exit(0)

name = data["name"]
print(f"=== {name} ===")

# Run summarize_structure.py with the scenario's file list
files_json = json.dumps(data["files"])
proc = subprocess.run(
    ["python3", script_path, "--json", files_json],
    capture_output=True, text=True,
)
if proc.returncode != 0:
    print(f"  FAIL: summarize_structure.py exited {proc.returncode}")
    print(f"    stderr: {proc.stderr.strip()}")
    print("RESULT:0:1")
    sys.exit(0)

out = json.loads(proc.stdout)
assertions = data["assertions"]
pass_count = 0
fail_count = 0


def check_pass(label):
    global pass_count
    print(f"  PASS: {label}")
    pass_count += 1


def check_fail(label, expected, actual):
    global fail_count
    print(f"  FAIL: {label}")
    print(f"    expected: {expected}")
    print(f"    actual:   {actual}")
    fail_count += 1


for key, expected in assertions.items():
    if key.endswith("_contains"):
        # Subset check: every expected item must appear in the actual value
        actual_key = key.removesuffix("_contains")
        actual = out.get(actual_key)
        if actual is None:
            check_fail(f"{actual_key} exists", "present", "missing")
            continue

        if isinstance(expected, dict):
            for k, v in expected.items():
                if isinstance(actual, dict) and actual.get(k) == v:
                    check_pass(f"{actual_key}[{k}] == {v}")
                else:
                    got = actual.get(k) if isinstance(actual, dict) else "N/A"
                    check_fail(f"{actual_key}[{k}]", v, got)
        elif isinstance(expected, list):
            for item in expected:
                if item in actual:
                    check_pass(f"{actual_key} contains '{item}'")
                else:
                    check_fail(f"{actual_key} contains '{item}'", item, actual)
    else:
        # Exact match
        actual = out.get(key)
        if actual == expected:
            check_pass(f"{key} == {json.dumps(expected)}")
        else:
            check_fail(key, json.dumps(expected), json.dumps(actual))

# Print manual checklist for behaviors requiring full skill execution
behaviors = data.get("expected_behavior", [])
if behaviors:
    print(f"\n  Manual verification ({len(behaviors)} items):")
    for b in behaviors:
        print(f"    [ ] {b}")

print(f"\nRESULT:{pass_count}:{fail_count}")
PYEOF
  )

  # Print output (excluding the RESULT line)
  echo "$result" | grep -v "^RESULT:"

  # Extract pass/fail counts from the RESULT line
  counts=$(echo "$result" | grep "^RESULT:" | tail -1)
  if [[ -n "$counts" ]]; then
    p=$(echo "$counts" | cut -d: -f2)
    f=$(echo "$counts" | cut -d: -f3)
    TOTAL_PASS=$((TOTAL_PASS + p))
    TOTAL_FAIL=$((TOTAL_FAIL + f))
  fi

  echo ""
done

echo "=== Eval total: $TOTAL_PASS passed, $TOTAL_FAIL failed ==="
[[ $TOTAL_FAIL -eq 0 ]]
