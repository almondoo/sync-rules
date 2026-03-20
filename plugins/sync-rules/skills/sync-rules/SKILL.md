---
name: sync-rules
description: >
  Analyzes project structure and config files to generate or sync .claude/rules/ with coding conventions,
  naming rules, test strategy, error handling, and architecture rules.
  Use when the user asks to generate rules, create coding conventions, set up project rules,
  sync existing rules, or organize .claude/rules files.
---

# sync-rules

Analyze a project's codebase and generate topic-based rule files in `.claude/rules/`.

## Checklist

You MUST create a task for each of these items and complete them in order:

1. **Analyze project** — scan files, read configs, detect patterns
2. **Determine paths patterns** — derive glob patterns from actual directory structure
3. **Check existing rules** — detect new/update/sync mode
4. **Present generation plan** — show file list with paths to user for approval
5. **Write rule files** — generate approved files to `.claude/rules/`
6. **Validate generated files** — run validation script and fix errors

## Step 1: Analyze Project

Read `references/analysis-guide.md` first to load analysis criteria.

Analysis uses a tiered approach: structure scan → compress → config read → targeted grep. Glob results never enter your context directly — they are compressed by a bundled script into a fixed-size JSON summary (~200 tokens), keeping token usage constant regardless of project size.

### 1-1. File Structure Scan

Run these Glob calls **in parallel** (a single message with multiple tool calls):

- Source files: `**/*.{ts,tsx,js,jsx,go,py,rs,java,rb,swift,kt,kts,cs,php}`
- Test files: `**/*.test.*`, `**/*.spec.*`, `**/*_test.*`, `**/test_*`, `**/tests/**`, `**/test/**`, `**/__tests__/**`, `**/spec/**`
- Config files: `package.json`, `tsconfig.json`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `requirements.txt`, `Gemfile`, `pom.xml`, `build.gradle`, `build.gradle.kts`, `settings.gradle.kts`, `.eslintrc*`, `eslint.config.*`, `.prettierrc*`, `prettier.config.*`, `biome.json`, `biome.jsonc`, `.editorconfig`, `.golangci.yml`, `.golangci.yaml`, `.rubocop.yml`, `rustfmt.toml`, `.rustfmt.toml`
  <!-- Keep config list in sync with CONFIG_PATTERNS/CONFIG_PREFIXES in scripts/summarize_structure.py -->

**Do NOT read or interpret the Glob results yourself.** Pass them to the compression script in the next step.

### 1-2. Compress Glob Results

Combine all file paths from Step 1-1 into a single newline-separated list and pipe to the bundled script.

Example (if Glob returned `src/app.ts`, `src/app.test.ts`, `package.json`):

```bash
printf '%s\n' 'src/app.ts' 'src/app.test.ts' 'package.json' | python3 scripts/summarize_structure.py
```

For large result sets, the `--json` flag is also available:

```bash
python3 scripts/summarize_structure.py --json '["src/app.ts", "src/app.test.ts", "package.json"]'
```

The script outputs a JSON summary:
```json
{
  "source_dirs": ["src/components", "src/api", "src/hooks"],
  "test_dirs": ["tests"],
  "test_patterns": ["*.test.ts", "*.test.tsx"],
  "extensions": {".ts": 42, ".tsx": 15},
  "config_files": ["package.json", "tsconfig.json", ".prettierrc"],
  "total_source_files": 57,
  "total_test_files": 12
}
```

This summary is your primary data source for all subsequent steps. It provides:
- `source_dirs` → paths patterns for rule files (Step 2)
- `test_dirs` / `test_patterns` → testing.md paths
- `extensions` → language detection and extension-based scoping
- `config_files` → which config files to read next
- `total_source_files` → project size classification

### 1-3. Read Config Files

Read **only** the files listed in `config_files` from the JSON summary. Run reads **in parallel** where possible.

Config files alone determine:
- Languages and frameworks (from dependency lists)
- Linter/formatter tools to defer to
- Test framework (from devDependencies or config sections)
- API framework presence (from dependencies)

After this phase, check what is still **unknown**. Typically, config files cannot tell you:
- Naming conventions (camelCase vs snake_case)
- Error handling patterns (custom error types, wrapping style)

### 1-4. Targeted Gap Detection (only when config leaves gaps)

**Skip this phase entirely** if the project has comprehensive linter config (e.g., ESLint with naming-convention rule, or ruff with N rules) that already defines the conventions you would detect.

When gaps remain, use **Grep with `head_limit`** instead of reading full files:

| Gap | Grep pattern | `head_limit` | Rationale |
|-----|-------------|-------------|-----------|
| Naming conventions | `function |const |def |func ` | 10 | Need enough samples to detect majority pattern |
| Error handling | `catch|if err != nil|raise |throw ` | 10 | Multiple error styles may coexist |
| API route detection | `app.get|router.get|@app.get|r.GET` | 5 | Presence/absence is sufficient; routes are uniform |
| Logging detection | `slog\.|logger\.|logging\.|console\.log` | 5 | Presence/absence is sufficient |

Grep `head_limit` caps results — even on a 10,000-file project, you get at most N matching lines per pattern.

### 1-5. Summarize Analysis

Organize results into:
- **Detected languages and frameworks**
- **Architecture pattern** (from `source_dirs` in JSON summary, matched against `references/analysis-guide.md` Section 2)
- **Existing linter/formatter settings**
- **Test patterns** (from `test_patterns` in JSON summary)
- **API layer presence**

## Step 2: Determine Paths Patterns

Derive `paths:` glob patterns for each rule file from the JSON summary produced in Step 1-2 (`source_dirs`, `test_dirs`, `test_patterns`, `extensions`). Patterns MUST be based on the project's actual directory structure — never use hardcoded values.

### Procedure

1. **Identify source directories**: Find top-level directories where source files concentrate (e.g., `src/`, `app/`, `lib/`, `internal/`, `pkg/`). This becomes the base for source globs.
2. **Identify test patterns**: Check test file placement — colocated (`src/**/*.test.ts`), separated (`tests/**/*`), or both.
3. **Identify API directories**: Find directories containing API-related files (`src/api/`, `routes/`, `handlers/`, `controllers/`, etc.).

### Pattern Construction Rules

- List multiple patterns on separate lines when multiple directories exist
- Only include test patterns actually used in the project (don't add `*.test.*` AND `*_test.*` if only one is used)
- Use `**/*.{ext}` when source files are scattered at root level
- Treat extensions with different purposes separately:
  - `.ts` and `.tsx` are different. `.tsx` = React components (UI layer), `.ts` = non-UI logic
  - `.js` and `.jsx` likewise
  - Do NOT include UI extensions (`.tsx`, `.jsx`) in API/service layer rules
  - Use brace expansion `*.{ts,tsx}` only when the same rule applies to both

### Examples

TypeScript + React project (`src/` directory):
```yaml
# testing.md — tests can be .ts or .tsx
paths:
  - "src/**/*.test.{ts,tsx}"
  - "src/**/*.spec.{ts,tsx}"

# error-handling.md, debugging.md — all source files
paths:
  - "src/**/*.{ts,tsx}"

# architecture.md — all source files
paths:
  - "src/**/*.{ts,tsx}"

# security.md — non-UI layer only
paths:
  - "src/**/*.ts"

# api-design.md — API layer only, .ts only (no .tsx)
paths:
  - "src/api/**/*.ts"
  - "src/routes/**/*.ts"
```

Go project (`internal/`, `cmd/`, `pkg/` layout):
```yaml
# testing.md
paths:
  - "**/*_test.go"

# security.md, error-handling.md, debugging.md, architecture.md
paths:
  - "internal/**/*.go"
  - "pkg/**/*.go"
  - "cmd/**/*.go"

# api-design.md
paths:
  - "internal/handler/**/*.go"
  - "internal/api/**/*.go"
```

## Step 3: Check Existing Rules

Search for `.claude/rules/**/*.md` with Glob.

### No existing rules → New mode

Proceed to Step 4.

### Existing rules found → Update mode

1. Read all existing rule files
2. Check each file for a comment starting with `<!-- generated-by: sync-rules`:
   - No metadata comment → user-created file. Preserve content, do not overwrite
   - Metadata comment found → auto-generated file. Proceed with update processing
3. Compare analysis results with existing rules and classify changes:
   - **Add**: new rules/sections based on newly detected patterns
   - **Update**: existing rules conflicting with changed settings
   - **Remove proposal**: rules no longer needed (e.g., migrated to linter)

Proceed to Step 4.

## Step 4: Present Generation Plan

Present the list of files to generate (or update) to the user.

### Candidate Files

| File | Condition | Paths |
|------|-----------|-------|
| `code-style.md` | Always | **None** (always loaded, max 200 lines) |
| `testing.md` | Test files exist | Test file patterns from Step 2 |
| `security.md` | Web/API project detected | Source directories + extensions from Step 2 |
| `api-design.md` | API layer detected | API directories + extensions from Step 2 |
| `error-handling.md` | Source files exist | Source directories + extensions from Step 2 |
| `debugging.md` | Logging library or observability tools detected | Source directories + extensions from Step 2 |
| `architecture.md` | Architecture pattern clearly detected | Source directories + extensions from Step 2 |

**Paths scope principles**:
- Only `code-style.md` has no paths (always loaded)
- All other files MUST have `paths:` frontmatter derived from Step 2
- Patterns are derived from actual project structure, never hardcoded

### Presentation Format

New mode:
```
## Rule Generation Plan

Based on analysis, the following rule files will be generated:

1. **code-style.md** (paths: none) — {summary}
2. **testing.md** (paths: `src/**/*.test.{ts,tsx}`) — {summary}
3. **error-handling.md** (paths: `src/**/*.{ts,tsx}`) — {summary}
4. ...

Proceed? Let me know if you want to skip any files or adjust paths.
```

Update mode:
```
## Rule Update Plan

### Add
- **security.md** — {reason}

### Update
- **code-style.md** — {change summary}

### Remove proposal
- **{filename}** — {reason}

Apply these changes?
```

Wait for user confirmation. Adjust the plan based on feedback.

## Step 5: Write Rule Files

Read `references/rule-format.md` to load format definitions. Follow all format rules defined there.

### New Mode

Write approved files to `.claude/rules/` using the Write tool.

Additional constraints for generation:
- One topic per file
- Do not duplicate rules managed by existing linter/formatter. State "Defer to {tool name}" instead
- Include Good/Bad code examples using detected language idioms
- Add a one-line rationale for each rule

### Update Mode

- Only update sections wrapped in `<!-- sync-rules:begin:{ID} -->` / `<!-- sync-rules:end:{ID} -->` markers using the Edit tool
- Preserve user-added sections outside markers
- Insert new sections before the unmarked user content area

### Monorepo

- Generate path-scoped rules per subdirectory
- Prefix filenames (e.g., `frontend-code-style.md`, `backend-code-style.md`)
- Place shared rules in separate files without `paths`

## Step 6: Validate Generated Files

Run the validation script on all generated or updated rule files:

```bash
python3 scripts/validate_rules.py .claude/rules/
```

The script checks frontmatter syntax, metadata comments, section marker pairs, line count limits, and code fence closure.

If validation fails:
1. Review the specific error messages
2. Fix the issues using the Edit tool
3. Run validation again
4. Only report completion when all files pass

## Constraints

- Use Glob/Grep/Read tools for analysis. The only permitted shell command is running bundled scripts in `scripts/` for data processing (e.g., `python3 scripts/summarize_structure.py`). Do NOT run arbitrary shell commands or install external tools
- Max 200 lines per rule file. Split into subtopics if exceeded
- Do NOT generate rules that conflict with existing linter/formatter settings
- Use `paths` frontmatter aggressively to limit rule scope
- Do NOT generate rules without evidence from the codebase. Base rules on actual project patterns, not generic advice
- Do NOT write files without user confirmation
- For languages not in the extension mapping (Elixir, Haskell, Dart, etc.), generate generic rules from file structure and config files. Omit language-specific idiom examples
- When naming conventions are mixed (e.g., camelCase and snake_case coexist), adopt the majority pattern and note the mixture in the rule

## Error Recovery

- **Compression script returns empty/error output**: Verify that Glob results are non-empty. If no source files match the extension list, report to the user that no analyzable source files were found
- **All Glob calls return zero results**: The project may use an unsupported language or unconventional structure. Ask the user for guidance on which files to analyze
- **Config files listed in summary are unreadable**: Skip unreadable files and note the gap in the analysis summary. Do not fail the entire workflow
- **User rejects the entire generation plan**: Ask what adjustments they want. Do not proceed without at least partial approval
- **Validation script reports failures**: Fix the specific issues and re-run validation. Do not report completion until all files pass
