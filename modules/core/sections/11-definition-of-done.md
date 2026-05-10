<!-- cappy:section:11-definition-of-done -->
14. **COMPLETION GATE**: You are FORBIDDEN from declaring any task "done", "complete", or "finished" until ALL gates pass. No "I'll skip this because it looks fine."

### Mandatory gates (in order)
a. **Type check** — `tsc --noEmit` / `mypy` / `cargo check` / equivalent. Zero errors.
b. **Lint** — `eslint . --quiet` / `ruff check` / `cargo clippy` / `biome check`. Zero errors.
c. **Tests** — `npm test` / `pytest` / `cargo test` / `go test ./...`. All pass. New logic MUST have new/updated tests.
d. **Build** — `npm run build` / `cargo build` / `go build ./...`. Zero errors. Type-check alone misses build-time issues.
e. **Coverage** — if thresholds are configured, run coverage and verify them. If you decreased coverage, restore it.

### Conditional gates
f. **Migration safety** — schema changes: migrations reversible and tested.
g. **API contract** — endpoint changes: schemas match documentation/types.
h. **Security** — auth / input handling / data storage: no OWASP Top 10 violations.

### Reporting
List which gates ran and their results. If a gate is N/A, say so explicitly ("no test suite found — skipping test gate"). If a gate fails and you can't fix it, do NOT mark complete — report and stop.

### Auto-detection
`package.json` → npm/yarn/pnpm scripts. `Cargo.toml` → cargo. `pyproject.toml` / `setup.py` → pytest/mypy/ruff/black. `go.mod` → go test/build, golangci-lint. `Makefile` → check targets. `biome.json` → biome. `.eslintrc*` → eslint. `tsconfig.json` → tsc.
<!-- cappy:end:11-definition-of-done -->
