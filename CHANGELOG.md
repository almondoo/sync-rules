# Changelog

## [1.0.4] - 2026-03-21

### Changed
- Consolidate 9-step workflow to 7 steps by merging Step 3+4 (Prepare Plan) and Step 8+9 (Validate & Summarize)
- Add content quality check (evidence, consistency, example accuracy) to validation step
- Fix incorrect step reference in rule-format.md

## [1.0.3] - 2026-03-20

### Added
- Result summary table (Step 9) showing added/updated/removed files after rule generation

## [1.0.2] - 2026-03-20

### Added
- Step 2 (Check CLAUDE.md) to detect contradictions and overlap with CLAUDE.md
- Per-rule-type path scoping guidelines for narrower rule file scope
- Rule Accuracy Guidelines (analysis-guide Section 7) to prevent overgeneralized rules
- Data File Detection (analysis-guide Section 8) for JSON/YAML/TOML data file rules
- Directory-level detection guidance for logging, security, and error-handling path scoping
- `data-files.md` as a candidate rule file
- CLAUDE.md test fixture with intentional contradiction and overlap

## [1.0.1] - 2026-03-20

### Added
- Tiered analysis with compression script and refined rule format
- Eval runner with machine-verifiable assertions
- Fixture projects and skill output verifier
- Shell tests for validate_rules.py (16 cases)

### Changed
- Improve sync-rules skill based on best practices evaluation
- Replace summarize_structure.py with prompt-based classification
- Remove count_files.py and add multi-language analysis strategy
- Consolidate 4 test scripts into single test_sync_rules.sh
- Run all fixtures when verify_skill_output.sh is called without args

### Fixed
- Treat fixtures without .claude/rules/ as passed instead of skipped
- Add golangci-lint deferral to go-update-mode fixture
- Use grep -F in test script to avoid regex interpretation of glob chars

## [1.0.0] - 2026-03-17

### Added
- Initial release
- Project analysis via Glob/Grep/Read tools
- Topic-based rule file generation (code-style, testing, security, api-design, error-handling, architecture, preferences, workflows)
- Update/sync mode with section-level markers
- Path-scoped rules for monorepo support
- Existing linter/formatter respect (ESLint, Prettier, Biome, etc.)
- Interactive preferences collection
