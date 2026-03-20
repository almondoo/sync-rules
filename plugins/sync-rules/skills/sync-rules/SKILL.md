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

Adapt the subagent strategy based on project characteristics. This keeps raw Glob results, config file contents, and Grep output out of your main context.

### Pre-assessment

Run parallel Glob calls for language config files only (fast, minimal context impact):
- `package.json`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `requirements.txt`, `Gemfile`, `pom.xml`, `build.gradle`, `build.gradle.kts`

Count distinct language-specific config files to determine the number of languages in the project.

### Strategy selection

**Single-language project** (1 language config, no monorepo indicators):

Spawn one Explore subagent (thoroughness: `very thorough`) that executes the full Analysis Procedure in `references/analysis-guide.md`. This is the simplest and most efficient path for typical projects.

**Prompt**: Read `references/analysis-guide.md` and follow the Analysis Procedure section. Execute all steps: parallel Glob scans, file classification (source/test/config), structure analysis, file path examination, config file reading, representative source file reading, and language-specific gap detection with Grep. Return the complete analysis summary as described in the Output Format subsection.

**Multi-language / monorepo project** (2+ language configs, or `packages/`/`apps/`/`services/` directories exist):

Spawn all subagents in parallel in a single message. Each subagent runs its own Glob and analysis independently — no sequential phase needed.

- **Structure + config analyzer** (Explore subagent, thoroughness: `medium`): Read `references/analysis-guide.md`. Run Glob for ALL source files and config files. Execute File Structure Scan, Classify Files, Analyze Structure, and Examine File Paths steps. Then read all detected config files and detect languages/frameworks (Section 1), linter/formatter deferral rules (Section 3), test framework (Section 4), API layer presence (Section 5), and logging/observability tools (Section 6). Return file classification, structure summary, directory observations, and all config-derived findings.

- **Source analyzer per language** (Explore subagent, thoroughness: `medium`, one per detected language from pre-assessment, max 3): Run Glob for `**/*.[ext]` files only. From the results, classify source vs test files, identify top source directories by file count, and select a representative file from each of the top 3 directories (prefer specific names over generic ones like index, main, types, utils). Read the representative files and examine import ordering, naming conventions, error handling style, comment style, function structure. Then run gap detection Grep using the Naming Convention and Error Handling pattern tables in `references/analysis-guide.md`, filtered to `*.[ext]` files with `head_limit: 30`. Return source code observations and grep findings.

Merge all subagent results into a unified analysis summary.

### Analysis summary

Regardless of strategy, the final analysis summary contains:
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
3. UI extensions (`.tsx`, `.jsx`) are excluded from non-UI rule files (`security.md`, `api-design.md`)
4. Test patterns in `testing.md` match only the naming conventions actually used in the project (not both `*.test.*` and `*_test.*` when only one exists)
5. Rules that should defer to a linter/formatter are planned to defer (cross-check config files with Section 3 of analysis-guide.md)
6. `code-style-{language}.md` filenames use the correct language suffix from Step 2's extension mapping (e.g., `kotlin` not `kt`)
7. No planned file is likely to exceed the 200-line limit; if so, a split plan exists
8. No planned rules lack evidence in the analysis summary
9. No contradictions between planned rule files
10. (Monorepo only) Per-language files have `paths:` scoped to subdirectories, not project root
11. (Update mode only) No user-created files (those without `<!-- generated-by: sync-rules` comment) are in the overwrite list
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

- Use Glob/Grep/Read tools for analysis. The only permitted shell command is running `python3 scripts/validate_rules.py`. Do NOT run arbitrary shell commands or install external tools
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
