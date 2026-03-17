# sync-rules

[日本語](README.ja.md)

A Claude Code plugin that analyzes your project's codebase and auto-generates `.claude/rules/` files for coding conventions.

## Features

- Analyzes source code patterns, directory structure, and config files
- Generates topic-based rule files (code style, testing, security, etc.)
- Respects existing linter/formatter settings (ESLint, Prettier, Biome, etc.)
- Supports update/sync mode to keep rules up-to-date
- Path-scoped rules for monorepo support
- Language-agnostic with language-specific idiom examples

## Installation

Add the marketplace and install the plugin:

```
/plugin marketplace add almondoo/sync-rules
/plugin install sync-rules@sync-rules-marketplace
```

## Usage

Run the skill in any project:

```
/sync-rules:sync-rules
```

The plugin will:
1. Scan your project structure, config files, and source code
2. Detect coding patterns, naming conventions, and architecture
3. Present a generation plan for your review
4. Generate `.claude/rules/` files after your approval

## Generated Rule Files

| File | Condition | Content |
|------|-----------|---------|
| `code-style.md` | Always | Indent, line length, imports, naming, function design |
| `testing.md` | Test files exist | Test structure, naming, mock strategy |
| `security.md` | Web/API project | Input validation, auth, secret management |
| `api-design.md` | API layer detected | Endpoint design, request/response format |
| `error-handling.md` | Source files exist | Error types, log levels, recovery patterns |
| `debugging.md` | Logging/observability tools detected | Logging conventions, debug tooling, observability |
| `architecture.md` | Architecture pattern detected | Dependency direction, layer responsibilities |
| `workflows.md` | CI/CD config detected | Branch strategy, PR conventions, deploy flow |

## Local Development

Test the plugin locally:

```
claude --plugin-dir ./plugins/sync-rules
```

## License

Apache-2.0
