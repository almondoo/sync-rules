#!/usr/bin/env python3
"""Count files by directory and extension.

For large projects (500+ files) where manual counting is impractical.

Usage:
    printf '%s\\n' path1 path2 | python3 count_files.py
    python3 count_files.py --json '["path1", "path2"]'
    python3 count_files.py --depth 3  # directory grouping depth (default: 4, 0 = no limit)
"""

import json
import os
import sys
from collections import Counter


def count(paths, depth=4):
    """Count files by directory and extension. Returns a JSON-serializable dict."""
    dirs = Counter()
    extensions = Counter()

    for path in paths:
        path = path.strip()
        if not path:
            continue

        ext = os.path.splitext(path)[1]
        if ext:
            extensions[ext] += 1

        parts = path.replace("\\", "/").split("/")
        if len(parts) <= 1:
            dirs["."] += 1
        else:
            dir_parts = parts[:-1]
            if depth > 0 and len(dir_parts) > depth:
                dir_parts = dir_parts[:depth]
            dirs["/".join(dir_parts)] += 1

    return {
        "dirs": dict(dirs.most_common()),
        "extensions": dict(extensions.most_common()),
        "total": sum(dirs.values()),
    }


def main():
    if len(sys.argv) > 1 and sys.argv[1] in ("--help", "-h"):
        print("Usage: python3 count_files.py [--json '<paths>'] [--depth N]")
        print("  Counts files by directory and extension.")
        print("  --json '<paths>'  Accept paths as a JSON array instead of stdin.")
        print("  --depth N         Directory grouping depth (default: 4, 0 = no limit).")
        sys.exit(0)

    argv = list(sys.argv[1:])
    depth = 4
    if "--depth" in argv:
        idx = argv.index("--depth")
        if idx + 1 >= len(argv):
            print(
                json.dumps({"error": "--depth requires a numeric argument"}),
                file=sys.stderr,
            )
            sys.exit(1)
        depth = int(argv[idx + 1])
        argv = argv[:idx] + argv[idx + 2:]

    if len(argv) >= 2 and argv[0] == "--json":
        try:
            paths = json.loads(argv[1])
        except json.JSONDecodeError as e:
            print(
                json.dumps({"error": f"Invalid JSON input: {e}"}),
                file=sys.stderr,
            )
            sys.exit(1)
        if not isinstance(paths, list):
            print(
                json.dumps({"error": "Expected JSON array of file paths"}),
                file=sys.stderr,
            )
            sys.exit(1)
    else:
        raw = sys.stdin.read().strip()
        if not raw:
            print(
                json.dumps({"error": "No input provided. Pipe file paths or use --json."}),
                file=sys.stderr,
            )
            sys.exit(1)
        paths = raw.split("\n")

    result = count(paths, depth=depth)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
