# {{PROJECT_NAME}} — Development Guide

## Tech Stack
- **Language**: Rust (latest stable)
- **Framework**: {{FRAMEWORK}}
- **Database**: {{DATABASE}} via {{ORM}}
- **Auth**: {{AUTH_METHOD}}

## Commands
```bash
cargo build            # Compile
cargo test             # Run tests
cargo clippy           # Lint
cargo check            # Type check (fast)
cargo run              # Start server
cargo fmt              # Format code
```

## Architecture
- `src/main.rs` — Entry point, server setup
- `src/config.rs` — Configuration and env vars
- `src/routes/` — HTTP route handlers
- `src/models/` — Database models and schemas
- `src/services/` — Business logic
- `src/errors.rs` — Error types and handling
- `tests/` — Integration tests

## Code Style
- Use `thiserror` for custom error types, `anyhow` in application code
- Prefer `impl` over `dyn` for known types
- All public functions must have doc comments
- Use `#[cfg(test)]` modules for unit tests alongside code
- No `unwrap()` in production code — use `?` operator
- Run `cargo clippy -- -W clippy::all` before committing
