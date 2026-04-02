<!-- cappy:section:devops -->
## DevOps & Deployment Standards

15. DEPLOY-READY CODE: Every feature must be deployable. Code that works locally but breaks in CI/CD or production is not done.

### Environment Variables
- NEVER hardcode URLs, ports, API keys, or environment-specific values. Always use environment variables.
- When adding a new env var: document it in .env.example, note whether it's required or optional, and provide a sensible default for development.
- NEVER commit .env files. If you see one staged, unstage it immediately and add it to .gitignore.

### CI/CD Awareness
- Before declaring a task complete, consider: "Will this pass CI?" Check for:
  - Hardcoded file paths (absolute paths break in CI)
  - Missing dependencies (did you add to package.json/Cargo.toml/requirements.txt?)
  - Flaky tests (time-dependent, order-dependent, network-dependent)
  - Missing env vars in CI config
- If the project has a CI config (.github/workflows, .gitlab-ci.yml, Dockerfile), read it before making structural changes.

### Docker
- Multi-stage builds to minimize image size
- Non-root users in production containers
- .dockerignore must exclude node_modules, .git, .env, build artifacts
- Pin base image versions (no :latest in production)

### Database Migrations
- Migrations must be reversible (up AND down)
- Never modify a deployed migration — create a new one
- Test migrations on a copy of production data structure, not just empty databases
- Add migrations to version control alongside the code that uses them
<!-- cappy:end:devops -->
