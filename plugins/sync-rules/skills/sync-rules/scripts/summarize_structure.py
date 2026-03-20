#!/usr/bin/env python3
"""Compress Glob file paths into a fixed-size JSON summary.

Usage:
    # Pipe file paths (one per line)
    echo "src/api/users.ts\nsrc/hooks/useAuth.ts" | python3 summarize_structure.py

    # Pass as JSON array
    python3 summarize_structure.py --json '["src/api/users.ts", "src/hooks/useAuth.ts"]'

Output is always ~200 tokens regardless of project size.
"""

import json
import os
import sys
from collections import Counter

# Config file patterns to detect
CONFIG_PATTERNS = {
    "package.json",
    "tsconfig.json",
    "go.mod",
    "Cargo.toml",
    "pyproject.toml",
    "requirements.txt",
    "Gemfile",
    "pom.xml",
    "build.gradle",
    "build.gradle.kts",
    "settings.gradle.kts",
    ".editorconfig",
    "biome.json",
    "biome.jsonc",
    ".rustfmt.toml",
}

CONFIG_PREFIXES = (
    ".eslintrc",
    ".prettierrc",
    ".golangci.",
    ".rubocop.",
    "rustfmt.",
    "eslint.config.",
    "prettier.config.",
)

SOURCE_EXTENSIONS = {
    ".ts", ".tsx", ".js", ".jsx", ".go", ".py", ".rs",
    ".java", ".rb", ".swift", ".kt", ".kts", ".cs", ".php",
}

TEST_DIR_NAMES = {"tests", "test", "__tests__", "spec"}


def is_config_file(path):
    basename = os.path.basename(path)
    if basename in CONFIG_PATTERNS:
        return True
    return any(basename.startswith(p) for p in CONFIG_PREFIXES)


def is_test_file(path):
    basename = os.path.basename(path)
    parts = path.replace("\\", "/").split("/")
    if any(d in TEST_DIR_NAMES for d in parts):
        return True
    if basename.startswith("test_"):
        return True
    return any(ind in basename for ind in [".test.", ".spec.", "_test."])


def detect_test_patterns(test_files):
    patterns = set()
    for f in test_files:
        basename = os.path.basename(f)
        if ".test." in basename:
            ext = os.path.splitext(basename)[1]
            patterns.add("*.test" + ext)
        elif ".spec." in basename:
            ext = os.path.splitext(basename)[1]
            patterns.add("*.spec" + ext)
        elif "_test." in basename:
            ext = os.path.splitext(basename)[1]
            patterns.add("*_test" + ext)
        elif basename.startswith("test_"):
            ext = os.path.splitext(basename)[1]
            patterns.add("test_*" + ext)
    return sorted(patterns)


def get_source_dir(path):
    parts = path.replace("\\", "/").split("/")
    if len(parts) <= 1:
        return "."
    return parts[0] if len(parts) == 2 else "/".join(parts[:2])


def summarize(paths):
    source_files = []
    test_files = []
    config_files = []
    extensions = Counter()

    for path in paths:
        if not path.strip():
            continue
        path = path.strip()

        if is_config_file(path):
            config_files.append(path)
            continue

        ext = os.path.splitext(path)[1]
        if ext not in SOURCE_EXTENSIONS:
            continue

        extensions[ext] += 1

        if is_test_file(path):
            test_files.append(path)
        else:
            source_files.append(path)

    source_dirs = sorted(set(get_source_dir(f) for f in source_files))
    test_dirs = sorted(set(get_source_dir(f) for f in test_files))
    test_patterns = detect_test_patterns(test_files)

    return {
        "source_dirs": source_dirs,
        "test_dirs": test_dirs,
        "test_patterns": test_patterns,
        "extensions": dict(extensions.most_common()),
        "config_files": sorted(config_files),
        "total_source_files": len(source_files),
        "total_test_files": len(test_files),
    }


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--json":
        paths = json.loads(sys.argv[2])
    else:
        paths = sys.stdin.read().strip().split("\n")

    result = summarize(paths)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
