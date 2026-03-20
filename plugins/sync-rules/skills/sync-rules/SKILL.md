---
name: sync-rules
description: >
  Analyzes project structure and config files to generate or sync .claude/rules/ with coding conventions,
  naming rules, test strategy, error handling, and architecture rules.
  Use when the user asks to generate rules, create coding conventions, set up project rules,
  sync existing rules, or organize .claude/rules files.
  Also triggered when working with a new project setup, when rules may be outdated,
  or when the user asks about coding standards for their project.
---

## Resources
- **Analysis criteria**: [references/analysis-guide.md](references/analysis-guide.md)
- **Rule format spec**: [references/rule-format.md](references/rule-format.md)
- **File counter (large projects only)**: `python3 scripts/count_files.py` (execute)
- **Rule validator**: `python3 scripts/validate_rules.py` (execute)

# sync-rules

Analyze a project's codebase and generate topic-based rule files in `.claude/rules/`.

## Checklist

You MUST create a task for each of these items and complete them in order:

- [ ] Step 1: Analyze project (scan files, read configs, detect patterns)
- [ ] Step 2: Determine path patterns (derive glob patterns)
- [ ] Step 3: Detect mode (new vs update)
- [ ] Step 4: Present plan (wait for user confirmation)
- [ ] Step 5: Review plan (subagent review loop until approved)
- [ ] Step 6: Write rule files
- [ ] Step 7: Validate generated files

## Step 1: Analyze Project

Spawn an exploration subagent to perform the full analysis. This keeps raw Glob results, config file contents, and Grep output out of your main context.

Use the Agent tool (subagent_type: `Explore`, thoroughness: `very thorough`):

**Prompt**: Read `references/analysis-guide.md` and follow the Analysis Procedure section. Execute all steps: parallel Glob scans, file classification (source/test/config), structure analysis, file path examination, config file reading, representative source file reading, and language-specific gap detection with Grep. For large projects (500+ source files), use `python3 scripts/count_files.py` for directory/extension counting. Return the complete analysis summary as described in the Output Format subsection.

The subagent returns a structured summary containing:
- **File classification**: source/test/config file counts, extension counts, test patterns, config files list
- **Source directories**: top directories by file count with representative files read
- **Languages and frameworks** detected from config files
- **Architecture pattern** (or "undetermined" if no clear match)
- **Directory structure observations** from direct file path examination
- **Linter/formatter tools** and which rules to defer
- **Test framework** and patterns
- **API layer** presence and directories
- **Source code observations** from representative files (import ordering, naming, error patterns, comment style)
- **Naming/error patterns** from Grep (if config gaps existed)

Use this summary as input for all subsequent steps.

## Step 2: Determine Paths Patterns

Derive `paths:` glob patterns for each rule file from the analysis summary returned in Step 1 (`source_dirs`, `test_dirs`, `test_patterns`, `extensions`). Patterns MUST be based on the project's actual directory structure — never use hardcoded values.

### Procedure

1. **Identify source directories**: Find top-level directories where source files concentrate (e.g., `src/`, `app/`, `lib/`, `internal/`, `pkg/`). This becomes the base for source globs.
2. **Identify test patterns**: Check test file placement — colocated (`src/**/*.test.ts`), separated (`tests/**/*`), or both.
3. **Identify API directories**: Find directories containing API-related files (`src/api/`, `routes/`, `handlers/`, `controllers/`, etc.).
4. **Map extensions to languages**: Use this mapping to determine the language suffix for `code-style-{language}.md` files:

| Extensions | Language suffix |
|---|---|
| `.ts`, `.tsx` | `typescript` |
| `.js`, `.jsx` | `javascript` |
| `.go` | `go` |
| `.py` | `python` |
| `.rs` | `rust` |
| `.java` | `java` |
| `.rb` | `ruby` |
| `.swift` | `swift` |
| `.kt`, `.kts` | `kotlin` |
| `.cs` | `csharp` |
| `.php` | `php` |

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
paths: ["src/**/*.test.{ts,tsx}", "src/**/*.spec.{ts,tsx}"]

# security.md — non-UI layer only (exclude .tsx)
paths: ["src/**/*.ts"]

# api-design.md — API layer only
paths: ["src/api/**/*.ts", "src/routes/**/*.ts"]

# error-handling.md, debugging.md, architecture.md — all source
paths: ["src/**/*.{ts,tsx}"]
```

Go project: use `**/*_test.go` for tests, `internal/**/*.go` + `pkg/**/*.go` + `cmd/**/*.go` for source, `internal/handler/**/*.go` for API.

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
| `code-style-{language}.md` | Source files exist for that language | Extension patterns from Step 2 (max 200 lines) |
| `testing.md` | Test files exist | Test file patterns from Step 2 |
| `security.md` | Web/API project detected | Source directories + extensions from Step 2 |
| `api-design.md` | API layer detected | API directories + extensions from Step 2 |
| `error-handling.md` | Source files exist | Source directories + extensions from Step 2 |
| `debugging.md` | Logging library or observability tools detected | Source directories + extensions from Step 2 |
| `architecture.md` | Architecture pattern clearly detected | Source directories + extensions from Step 2 |

**Paths scope principles**:
- All rule files MUST have `paths:` frontmatter derived from Step 2
- Patterns are derived from actual project structure, never hardcoded

### Presentation Format

Present the plan as a numbered list with filename, glob paths, and one-line summary per file.
For update mode, group changes by Add / Update / Remove.
Wait for user confirmation before proceeding.

## Step 5: Review Plan

Spawn a review subagent to verify the generation plan and analysis results before writing any files. This catches issues early — before they become rule files that need fixing.

Use the Agent tool (subagent_type: `code-reviewer`):

**Prompt**: Review the rule generation plan and analysis summary. For each planned rule file, verify:
1. The file's inclusion condition is met (e.g., testing.md requires test files to exist)
2. `paths:` patterns correctly scope to the intended directories (check against the analysis summary's `source_dirs`)
3. Rules that should defer to a linter/formatter are planned to defer (cross-check config files with Section 3 of analysis-guide.md)
4. No planned rules lack evidence in the analysis summary
5. No contradictions between planned rule files
Report issues as a list with planned file name and what is wrong. If no issues found, respond with APPROVE.

### Review Loop

1. If the subagent returns **APPROVE** → proceed to Step 6
2. If the subagent returns **issues** →
   a. Adjust the plan (modify paths, add/remove files, update deferral rules)
   b. Present the revised plan to the user for confirmation
   c. Spawn the review subagent again with the same prompt
   d. Repeat until APPROVE or 3 iterations reached
3. If 3 iterations pass without APPROVE → report remaining issues to the user for guidance

## Step 6: Write Rule Files

Read `references/rule-format.md` to load format definitions. Follow all format rules defined there.

### New Mode

Write approved files to `.claude/rules/` using the Write tool.

### Update Mode

- Only update sections wrapped in `<!-- sync-rules:begin:{ID} -->` / `<!-- sync-rules:end:{ID} -->` markers using the Edit tool
- Preserve user-added sections outside markers
- Insert new sections before the unmarked user content area

### Monorepo

- Generate per-language files (`code-style-{language}.md`) with `paths:` scoped to the subdirectory (e.g., `paths: ["backend/**/*.go"]`). No filename prefixing
- Place shared rules in separate files with `paths:` covering all relevant directories

## Step 7: Validate Generated Files

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

- Use Glob/Grep/Read tools for analysis. The only permitted shell commands are running bundled scripts in `scripts/` (e.g., `python3 scripts/count_files.py` for large projects, `python3 scripts/validate_rules.py`). Do NOT run arbitrary shell commands or install external tools
- Do NOT generate rules that conflict with existing linter/formatter settings
- Use `paths` frontmatter aggressively to limit rule scope
- Do NOT generate rules without evidence from the codebase. Base rules on actual project patterns, not generic advice
- Do NOT write files without user confirmation
- For languages not in the extension mapping (Elixir, Haskell, Dart, etc.), generate generic rules from file structure and config files. Omit language-specific idiom examples
- When naming conventions are mixed (e.g., camelCase and snake_case coexist), adopt the majority pattern and note the mixture in the rule

## Error Recovery

- **No source files found**: Verify that Glob results are non-empty. If no source files match the extension list, report to the user that no analyzable source files were found
- **All Glob calls return zero results**: The project may use an unsupported language or unconventional structure. Ask the user for guidance on which files to analyze
- **Config files listed in summary are unreadable**: Skip unreadable files and note the gap in the analysis summary. Do not fail the entire workflow
- **User rejects the entire generation plan**: Ask what adjustments they want. Do not proceed without at least partial approval
- **Validation script reports failures**: Fix the specific issues and re-run validation. Do not report completion until all files pass
