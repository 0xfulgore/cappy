<!-- cappy:section:11-definition-of-done -->
## Definition of Done

11. COMPLETION GATE: You are FORBIDDEN from declaring any task "done", "complete", or "finished" until ALL of the following gates pass. No exceptions, no "I'll skip this because it looks fine."

### Mandatory Gates (run in this order):
a. **Type Check**: Run the project's type checker (`npx tsc --noEmit`, `mypy`, `cargo check`, etc.). Zero errors.
b. **Lint**: Run the project's linter (`npx eslint . --quiet`, `ruff check .`, `cargo clippy`, `biome check .`). Zero errors, zero warnings treated as errors.
c. **Tests**: Run the project's test suite (`npm test`, `pytest`, `cargo test`, `go test ./...`). All tests pass. If you added new logic, you MUST add or update tests covering it.
d. **Build**: Run the project's build command (`npm run build`, `cargo build`, `go build ./...`). Zero errors. Do not skip this — type-check alone does not catch build-time issues (missing imports, asset resolution, env vars).
e. **Coverage Check** (if configured): If the project has coverage thresholds, run coverage and verify thresholds are met. If you decreased coverage, add tests to restore it.

### Conditional Gates:
f. **Migration Safety**: If you modified database schemas, verify migrations are reversible and tested.
g. **API Contract**: If you changed API endpoints, verify request/response schemas match documentation or types.
h. **Security Scan**: If you touched auth, input handling, or data storage, verify no OWASP Top 10 violations.

### Reporting:
- When completing a task, explicitly list which gates you ran and their results.
- If a gate is not applicable (e.g., no test suite configured), state that explicitly: "No test suite found — skipping test gate."
- If a gate fails and you cannot fix it, do NOT mark the task complete. Report the failure and stop.

### Auto-Detection:
Detect the project's toolchain by checking for:
- `package.json` → npm/yarn/pnpm commands, check `scripts` for test/lint/build
- `Cargo.toml` → cargo test/check/clippy/build
- `pyproject.toml` or `setup.py` → pytest/mypy/ruff/black
- `go.mod` → go test/go build/golangci-lint
- `Makefile` → check for test/lint/build targets
- `biome.json` → biome check
- `.eslintrc*` → eslint
- `tsconfig.json` → tsc --noEmit
<!-- cappy:end:11-definition-of-done -->
