# Project Analysis Guide

## Contents
- [Analysis Procedure](#analysis-procedure) — step-by-step exploration procedure for subagent
- [1. Language Detection](#1-language-detection) — extension mapping, framework detection, monorepo detection
- [2. Architecture Pattern Detection](#2-architecture-pattern-detection) — directory-based inference
- [3. Linter / Formatter Compatibility](#3-linter--formatter-compatibility-checklist) — tool deferral rules
- [4. Test Pattern Classification](#4-test-pattern-classification) — file patterns, framework detection
- [5. API Layer / Web Project Detection](#5-api-layer--web-project-detection) — route handlers, directories, dependencies
- [6. Debugging / Logging Detection](#6-debugging--logging-detection) — logging libraries, observability tools

## Analysis Procedure

This section defines the step-by-step procedure for analyzing a project. This procedure runs inside a subagent, so token efficiency is secondary to analysis accuracy. Follow these steps in order.

### File Structure Scan

Run these Glob calls **in parallel** (a single message with multiple tool calls):

- Source files: `**/*.{ts,tsx,js,jsx,go,py,rs,java,rb,swift,kt,kts,cs,php}`
- Config files: `package.json`, `tsconfig.json`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `requirements.txt`, `Gemfile`, `pom.xml`, `build.gradle`, `build.gradle.kts`, `settings.gradle.kts`, `.eslintrc*`, `eslint.config.*`, `.prettierrc*`, `prettier.config.*`, `biome.json`, `biome.jsonc`, `.editorconfig`, `.golangci.yml`, `.golangci.yaml`, `.rubocop.yml`, `rustfmt.toml`, `.rustfmt.toml`

### Classify Files

From the Glob results, classify each file path into one of three categories:

**Config files** — files matching known config names or prefixes:
- Exact names: `package.json`, `tsconfig.json`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `requirements.txt`, `Gemfile`, `pom.xml`, `build.gradle`, `build.gradle.kts`, `settings.gradle.kts`, `.editorconfig`, `biome.json`, `biome.jsonc`, `.rustfmt.toml`
- Name prefixes: `.eslintrc`, `.prettierrc`, `.golangci.`, `.rubocop.`, `rustfmt.`, `eslint.config.`, `prettier.config.`

**Test files** — files matching test naming conventions. Classify by **file name pattern**, not just by parent directory:
- `*.test.*`, `*.spec.*` (e.g., `user.test.ts`, `app.spec.tsx`)
- `*_test.*` (e.g., `user_test.go`, `handler_test.rs`)
- `test_*.*` (e.g., `test_user.py`)

Use directory context to disambiguate edge cases. For example, `tests/fixtures/app/main.go` is a fixture file, not a test. Files in `__tests__/` or `spec/` directories that match naming patterns above are tests; other files in those directories are test helpers.

**Source files** — all remaining files with recognized source extensions (see Section 1 Extension Mapping).

### Analyze Structure

From the classified files, build a structural summary:

1. **Count files by directory**: Group source files by parent directory and note file counts per directory. Identify the top 3 directories by file count — these are the most important areas of the project.

2. **Count files by extension**: Tally extensions across all source files. This determines the project's primary languages.

3. **Identify test patterns**: Note which test naming conventions the project uses (e.g., `*.test.ts`, `*_test.go`). Check test file placement — colocated with source (`src/**/*.test.ts`), separated (`tests/**/*`), or both.

4. **List config files**: Collect all detected config file paths.

### Examine File Paths

Scan the raw Glob results directly to detect architectural signals. Report any directory structure patterns that reveal the project's organizational intent — layering, feature grouping, infrastructure abstraction, API versioning, test colocation strategy, etc.

Do not limit observations to a fixed checklist. The goal is to capture any structural pattern that would inform rule generation.

### Read Config Files

Read the detected config files. Run reads **in parallel** where possible.

Config files determine:
- Languages and frameworks (from dependency lists)
- Linter/formatter tools to defer to (see Section 3 below)
- Test framework (from devDependencies or config sections, see Section 4)
- API framework presence (from dependencies, see Section 5)

After this phase, check what is still **unknown**. Typically, config files cannot tell you:
- Naming conventions (camelCase vs snake_case)
- Error handling patterns (custom error types, wrapping style)
- Import ordering conventions
- Comment and documentation style

### Read Representative Source Files

From the top 3 source directories by file count, select one representative file each. Prefer files with specific, descriptive names that are likely to contain substantive implementation patterns. Avoid files with generic names like `index`, `mod`, `main`, `types`, `constants`, `config`, `utils`, `helpers`, `init`, or `setup` — these typically contain boilerplate rather than project-specific patterns.

Examine each file for concrete coding patterns: import ordering, naming conventions, error handling style, comment style, function structure, and file organization. Report what you observe — these direct observations produce more specific and accurate rules than Grep alone.

### Targeted Gap Detection

**Skip this phase entirely** if the project has comprehensive linter config (e.g., ESLint with naming-convention rule, or ruff with N rules) that already defines the conventions you would detect.

When gaps remain after reading config and source files, run **language-specific** Grep queries using the patterns below. Filter by file extension (use the `glob` parameter) to avoid cross-language noise (e.g., mixing Go `func` with Python `def`).

#### Naming Convention Patterns

| Extension(s) | Grep pattern | `head_limit` |
|---|---|---|
| `.ts` | `function \|const \|class \|interface \|type ` | 30 |
| `.tsx` | `function \|const \|class ` | 30 |
| `.js`, `.jsx` | `function \|const \|class ` | 30 |
| `.go` | `func \|type \|var ` | 30 |
| `.py` | `def \|class ` | 30 |
| `.rs` | `fn \|struct \|enum \|trait \|impl ` | 30 |
| `.java` | `public \|private \|protected \|class \|interface ` | 30 |
| `.rb` | `def \|class \|module ` | 30 |
| `.swift` | `func \|class \|struct \|enum \|protocol ` | 30 |
| `.kt`, `.kts` | `fun \|class \|interface \|object \|val \|var ` | 30 |
| `.cs` | `public \|private \|class \|interface \|struct ` | 30 |
| `.php` | `function \|class \|interface \|trait ` | 30 |

#### Error Handling Patterns

| Extension(s) | Grep pattern | `head_limit` |
|---|---|---|
| `.ts`, `.tsx`, `.js`, `.jsx` | `catch \(\|catch\(\|throw new \|\.catch\(` | 30 |
| `.go` | `if err != nil\|errors\.New\|fmt\.Errorf\|errors\.Wrap` | 30 |
| `.py` | `except \|raise \|try:` | 30 |
| `.rs` | `\.unwrap\(\|\.expect\(\|\?;\|Err\(` | 30 |
| `.java` | `catch \(\|throw new \|throws ` | 30 |
| `.rb` | `rescue \|raise \|begin$` | 30 |
| `.swift` | `catch \|throw \|try \|guard ` | 30 |
| `.kt`, `.kts` | `catch \(\|throw \|try \{` | 30 |
| `.cs` | `catch \(\|throw new \|throw;` | 30 |
| `.php` | `catch \(\|throw new ` | 30 |

#### API and Logging Detection

| Gap | Grep pattern | `head_limit` |
|-----|-------------|-------------|
| API route detection | `app.get\|router.get\|@app.get\|r.GET` | 20 |
| Logging detection | `slog\.\|logger\.\|logging\.\|console\.log` | 20 |

### Output Format

Return a structured summary including:
- **File classification**: source file count, test file count, config files list, extension counts, test patterns detected
- **Source directories**: top directories by file count with representative files read
- **Languages and frameworks** detected from config files (see Section 1)
- **Architecture pattern** matched against Section 2 (or "undetermined" if no clear match)
- **Directory structure observations** from file path examination (notable patterns, layering, organization)
- **Linter/formatter tools** and deferral rules from Section 3
- **Test framework** and patterns from Section 4
- **API layer presence** and directories from Section 5
- **Logging/observability** detected per Section 6
- **Source code observations** from representative files read (import ordering, naming style, error patterns, comment style)
- **Naming/error handling patterns** from Grep (if gaps existed)

## 1. Language Detection

### Extension Mapping

| Extension | Language |
|-----------|----------|
| `.ts`, `.tsx` | TypeScript |
| `.js`, `.jsx` | JavaScript |
| `.go` | Go |
| `.py` | Python |
| `.rs` | Rust |
| `.java` | Java |
| `.rb` | Ruby |
| `.swift` | Swift |
| `.kt`, `.kts` | Kotlin |
| `.cs` | C# |
| `.php` | PHP |

### Config File → Framework Detection

| Config File | Additional Condition | Framework |
|-------------|---------------------|-----------|
| `package.json` | dependencies includes `react` | React |
| `package.json` | dependencies includes `@remix-run/*` | Remix |
| `package.json` | dependencies includes `next` | Next.js |
| `package.json` | dependencies includes `vue` | Vue.js |
| `package.json` | dependencies includes `@angular/core` | Angular |
| `package.json` | dependencies includes `express` | Express |
| `package.json` | dependencies includes `fastify` | Fastify |
| `package.json` | dependencies includes `hono` | Hono |
| `go.mod` | requires `gin-gonic/gin` | Gin |
| `go.mod` | requires `labstack/echo` | Echo |
| `go.mod` | requires `go-chi/chi` | Chi |
| `Cargo.toml` | dependencies includes `actix-web` | Actix Web |
| `Cargo.toml` | dependencies includes `axum` | Axum |
| `pyproject.toml` / `requirements.txt` | `django` | Django |
| `pyproject.toml` / `requirements.txt` | `fastapi` | FastAPI |
| `pyproject.toml` / `requirements.txt` | `flask` | Flask |
| `Gemfile` | `rails` | Ruby on Rails |
| `build.gradle` / `pom.xml` | `spring-boot` | Spring Boot |

### Monorepo Detection

Classify as monorepo if any of the following are true:
- Multiple language-specific config files at top level (e.g., `go.mod` + `package.json`)
- `packages/`, `apps/`, or `services/` directories exist
- Top-level `package.json` has `workspaces` field
- Subdirectories contain source files in different languages

## 2. Architecture Pattern Detection

Infer architecture from directory name patterns. **When multiple patterns match, adopt the one with the most matches.**

| Directory Name Pattern | Architecture |
|----------------------|--------------|
| `domain/`, `application/`, `infrastructure/`, `presentation/` | DDD (Domain-Driven Design) |
| `controller/`, `service/`, `repository/`, `model/` | Layered Architecture |
| `handler/`, `usecase/`, `entity/`, `gateway/` | Clean Architecture |
| `features/`, `shared/`, `entities/`, `widgets/` | Feature-Sliced Design |
| `internal/`, `pkg/`, `cmd/` | Go Standard Layout |
| `components/`, `hooks/`, `pages/`, `layouts/` | React / Frontend SPA |
| `routes/`, `middleware/`, `plugins/` | Web Framework Standard |

**When undetermined**: If no pattern clearly matches, do NOT generate `architecture.md`.

## 3. Linter / Formatter Compatibility Checklist

Avoid duplicating rules managed by existing tools:

| Detected File | Impact on Generated Rules |
|--------------|--------------------------|
| `biome.json` / `biome.jsonc` | Do not generate indent, quote, semicolon, import order rules. State "Defer to Biome" |
| `.eslintrc*` / `eslint.config.*` | State "Defer to ESLint" for ESLint-managed rules (no-unused-vars, naming-convention, etc.) |
| `.prettierrc*` / `prettier.config.*` | State "Defer to Prettier" for formatting rules (indent, line length, quotes) |
| `.editorconfig` | State "Defer to .editorconfig" for indent, line ending, charset, trailing newline |
| `.golangci.yml` / `.golangci.yaml` | State "Defer to golangci-lint" for Go static analysis rules |
| `.rubocop.yml` | State "Defer to RuboCop" for Ruby style rules |
| `pyproject.toml` (ruff/black section) | Defer Python formatting/lint rules to the respective tool |
| `.clang-format` | State "Defer to clang-format" for C/C++ formatting |
| `rustfmt.toml` / `.rustfmt.toml` | State "Defer to rustfmt" for Rust formatting |

## 4. Test Pattern Classification

### File Name Patterns

| Pattern | Language | Example |
|---------|----------|---------|
| `*_test.go` | Go | `user_test.go` |
| `*.test.ts` / `*.test.tsx` | TypeScript | `user.test.ts` |
| `*.spec.ts` / `*.spec.tsx` | TypeScript | `user.spec.ts` |
| `test_*.py` / `*_test.py` | Python | `test_user.py` |
| `*_test.rs` | Rust | `user_test.rs` |
| `*Test.java` / `*Spec.java` | Java | `UserTest.java` |
| `*_test.rb` / `*_spec.rb` | Ruby | `user_test.rb` |

### Test Framework Detection

| Detection Method | Framework |
|-----------------|-----------|
| package.json devDependencies includes `vitest` | Vitest |
| package.json devDependencies includes `jest` | Jest |
| package.json devDependencies includes `mocha` | Mocha |
| Go project (uses `go test`) | Go testing |
| pyproject.toml / setup.cfg includes `pytest` | pytest |
| Gemfile includes `rspec` | RSpec |
| Cargo.toml (Rust projects use built-in tests) | Rust #[test] |
| build.gradle / pom.xml includes `junit` | JUnit |

## 5. API Layer / Web Project Detection

Classify as Web/API project if any of the following match (triggers `security.md` and `api-design.md`):

### Route Handler Patterns (detect with Grep)
- Express: `app.get(`, `app.post(`, `router.get(`
- Gin: `r.GET(`, `r.POST(`, `router.GET(`
- FastAPI: `@app.get(`, `@app.post(`, `@router.get(`
- Echo: `e.GET(`, `e.POST(`
- Chi: `r.Get(`, `r.Post(`
- Hono: `app.get(`, `app.post(`
- Rails: `resources :`, `get '`, `post '`
- Spring: `@GetMapping`, `@PostMapping`, `@RequestMapping`

### Directory / File Existence
- `api/`, `routes/`, `handlers/`, `endpoints/`, `controllers/` directories
- `openapi.yaml`, `openapi.json`, `swagger.yaml`, `swagger.json`

### Dependency Packages
- HTTP frameworks (Web-related entries from the framework detection table above)

## 6. Debugging / Logging Detection

Classify as needing `debugging.md` if any of the following match:

### Logging Libraries
- package.json dependencies: `winston`, `pino`, `bunyan`, `log4js`
- Go: `log/slog`, `go.uber.org/zap`, `sirupsen/logrus`
- Python: `logging` module usage, `loguru`
- Rust: `tracing`, `log`, `env_logger`
- Java: `slf4j`, `log4j`, `logback`

### Observability Tools
- `@opentelemetry/*`, `opentelemetry-*` packages
- `datadog`, `sentry`, `newrelic` related packages
- Prometheus metrics (`prom-client`, `prometheus/*`)

### Logging Patterns (detect with Grep)
- `console.log(`, `console.error(`, `console.warn(`
- `logger.info(`, `logger.error(`, `logger.debug(`
- `log.Printf(`, `log.Println(`, `slog.Info(`

