#!/usr/bin/env python3
"""Validate generated rule files in .claude/rules/.

Usage:
    python3 validate_rules.py <rules_directory>
    python3 validate_rules.py .claude/rules/

Checks:
- Frontmatter YAML syntax (paths: field present if expected)
- Metadata comment presence (generated-by: sync-rules)
- Section marker pairs (every begin has a matching end)
- Section ID uniqueness within each file
- Line count <= 200
- Code block fence closure
"""

import os
import re
import sys

MAX_LINES = 200

METADATA_RE = re.compile(
    r"<!--\s*generated-by:\s*sync-rules,\s*last-synced:\s*\d{4}-\d{2}-\d{2}\s*-->"
)
BEGIN_RE = re.compile(r"<!--\s*sync-rules:begin:([a-z0-9-]+)\s*-->")
END_RE = re.compile(r"<!--\s*sync-rules:end:([a-z0-9-]+)\s*-->")
FENCE_RE = re.compile(r"^(`{3,})")


def validate_file(filepath):
    """Validate a single rule file. Returns a list of error strings."""
    errors = []
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    lines = content.split("\n")
    filename = os.path.basename(filepath)

    # 1. Line count
    if len(lines) > MAX_LINES:
        errors.append(f"Exceeds {MAX_LINES}-line limit: {len(lines)} lines")

    # 2. Frontmatter
    has_frontmatter = content.startswith("---\n")
    if has_frontmatter:
        end_idx = content.find("\n---\n", 4)
        if end_idx == -1:
            errors.append("Frontmatter opened but never closed (missing closing '---')")
        elif "paths:" not in content[4:end_idx]:
            errors.append("Frontmatter present but missing 'paths:' field")

    if filename == "code-style.md" and has_frontmatter:
        errors.append(
            "code-style.md must not have frontmatter (applies to all files)"
        )
    elif filename != "code-style.md" and not has_frontmatter:
        errors.append(
            "Missing paths: frontmatter (required for all files except code-style.md)"
        )

    # 3. Metadata comment
    if not METADATA_RE.search(content):
        errors.append(
            "Missing metadata comment: "
            "<!-- generated-by: sync-rules, last-synced: YYYY-MM-DD -->"
        )

    # 4. Section markers
    begin_ids = BEGIN_RE.findall(content)
    end_ids = END_RE.findall(content)

    seen = set()
    for sid in begin_ids:
        if sid in seen:
            errors.append(f"Duplicate section ID: {sid}")
        seen.add(sid)

    begin_set = set(begin_ids)
    end_set = set(end_ids)

    for sid in sorted(begin_set - end_set):
        errors.append(f"Unclosed section (missing end marker): {sid}")
    for sid in sorted(end_set - begin_set):
        errors.append(f"Orphaned end marker (no matching begin): {sid}")

    for sid in begin_set & end_set:
        begin_pos = content.index(f"sync-rules:begin:{sid}")
        end_pos = content.index(f"sync-rules:end:{sid}")
        if begin_pos > end_pos:
            errors.append(
                f"Section '{sid}': end marker appears before begin marker"
            )

    # 5. Code fences
    in_fence = False
    fence_start = 0
    fence_ticks = 0

    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        m = FENCE_RE.match(stripped)
        if m:
            count = len(m.group(1))
            if not in_fence:
                in_fence = True
                fence_start = i
                fence_ticks = count
            elif count >= fence_ticks and stripped == "`" * count:
                in_fence = False

    if in_fence:
        errors.append(f"Unclosed code fence starting at line {fence_start}")

    return errors


def main():
    if len(sys.argv) < 2:
        print(
            "Usage: python3 validate_rules.py <rules_directory>",
            file=sys.stderr,
        )
        sys.exit(1)

    rules_dir = sys.argv[1]
    if not os.path.isdir(rules_dir):
        print(f"Error: '{rules_dir}' is not a directory", file=sys.stderr)
        sys.exit(1)

    md_files = sorted(f for f in os.listdir(rules_dir) if f.endswith(".md"))
    if not md_files:
        print(f"No .md files found in {rules_dir}")
        sys.exit(0)

    all_passed = True
    for filename in md_files:
        filepath = os.path.join(rules_dir, filename)
        errors = validate_file(filepath)

        if errors:
            all_passed = False
            print(f"FAIL: {filename}")
            for err in errors:
                print(f"  - {err}")
        else:
            print(f"  OK: {filename}")

    print()
    if all_passed:
        print(f"All {len(md_files)} file(s) passed validation.")
    else:
        print("Validation failed. Fix errors above and re-run.")
        sys.exit(1)


if __name__ == "__main__":
    main()
