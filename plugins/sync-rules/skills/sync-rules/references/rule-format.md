# Rule File Structure Definition

This document defines the format for rule files generated in `.claude/rules/`.

## 1. Frontmatter Format

Claude Code only recognizes `paths:` in `.claude/rules` frontmatter. All other metadata goes in HTML comments.

### Paths Scope (only when needed)

Add `paths:` frontmatter only for rules scoped to specific files. Rules that apply to all files (only `code-style.md`) get NO frontmatter.

```yaml
---
paths:
  - "src/**/*.{ts,tsx}"
  - "lib/**/*.ts"
---
```

### Metadata Comment

All generated rule files MUST include the following HTML comment **after** the frontmatter block (or at the very top for files without frontmatter like `code-style.md`):

```markdown
<!-- generated-by: sync-rules, last-synced: YYYY-MM-DD -->
```

- `generated-by`: Plugin name. Used to distinguish auto-generated files from user-created files in update mode
- `last-synced`: Generation/update date for freshness tracking

The metadata comment goes after frontmatter because Claude Code expects `---` delimiters at the very start of the file to parse `paths:` correctly. Placing anything before frontmatter breaks path scoping.

## 2. File Structure Template

```markdown
---
paths:
  - "src/**/*.ts"
---
<!-- generated-by: sync-rules, last-synced: YYYY-MM-DD -->

# {Topic Name}

<!-- sync-rules:begin:{section-id} -->
## {Section Heading}

- **Rule**: {rule content}
  - Rationale: {why this rule is needed (one sentence)}

### Examples

```{lang}
// Good: {description}
{good example code}

// Bad: {description}
{bad example code}
```

<!-- sync-rules:end:{section-id} -->
```

### Section Marker Naming

`{section-id}` follows these conventions:
- Kebab-case (e.g., `import-order`, `naming-variables`, `error-types`)
- Must be unique within the file
- Do NOT prefix with topic name (the file itself represents the topic)

## 3. Writing Rules

### Rule Format
- Write each rule as a bullet point (`-`)
- Add a one-line "Rationale" for each rule
- Be specific and verifiable — avoid abstract instructions
  - Bad: "Write clean code"
  - Good: "Limit function parameters to 4. Use an options object/struct when more are needed"

### Good / Bad Examples
- Include at least one Good/Bad example per section
- Write examples using detected language idioms
- Add language identifiers to code blocks (```ts, ```go, ```py, etc.)

### Deferring to Existing Tools
- Do NOT duplicate rules managed by linter/formatter
- Use the format: "{rule topic} — defer to {tool name}"
- Example: "Indent style — defer to Biome"

### File Size Limit
- Max 200 lines per file
- Split into subtopics when exceeded
  - Example: `code-style.md` → `code-style-imports.md` + `code-style-naming.md`
- Each split file gets its own frontmatter
