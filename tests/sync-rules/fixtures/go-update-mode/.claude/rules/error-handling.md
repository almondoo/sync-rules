---
paths:
  - "internal/**/*.go"
  - "pkg/**/*.go"
  - "cmd/**/*.go"
---

# Error Handling

## Custom error types

- Always wrap errors with context using fmt.Errorf with %w
- Define domain errors in internal/errors package
