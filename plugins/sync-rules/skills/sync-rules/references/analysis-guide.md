# Project Analysis Guide

## Contents
- [1. Language Detection](#1-language-detection) — extension mapping, framework detection, monorepo detection
- [2. Architecture Pattern Detection](#2-architecture-pattern-detection) — directory-based inference
- [3. Linter / Formatter Compatibility](#3-linter--formatter-compatibility-checklist) — tool deferral rules
- [4. Test Pattern Classification](#4-test-pattern-classification) — file patterns, framework detection
- [5. API Layer / Web Project Detection](#5-api-layer--web-project-detection) — route handlers, directories, dependencies
- [6. Debugging / Logging Detection](#6-debugging--logging-detection) — logging libraries, observability tools

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

