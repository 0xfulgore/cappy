<!-- cappy:section:api-design -->
## API Design Standards

19. API QUALITY: Every API endpoint must be consistent, well-documented, and defensively designed. APIs are contracts — treat them with the same rigor as database schemas.

### REST Conventions
- Use plural nouns for resources: `/users`, `/orders`, `/products`
- Use HTTP methods correctly: GET (read), POST (create), PUT/PATCH (update), DELETE (remove)
- Return appropriate status codes: 200 (ok), 201 (created), 204 (no content), 400 (bad input), 401 (unauthenticated), 403 (forbidden), 404 (not found), 422 (validation), 500 (server error)
- Use consistent response envelope:
  ```json
  { "data": {...}, "meta": { "page": 1, "total": 100 } }
  { "error": { "code": "VALIDATION_ERROR", "message": "...", "details": [...] } }
  ```

### Input Validation
- Validate ALL input at the API boundary — never trust the client
- Use schema validation (Zod, Joi, JSON Schema, serde) — not manual if/else chains
- Return specific error messages: "email must be a valid email address", not "invalid input"
- Sanitize strings to prevent injection (SQL, NoSQL, XSS, command injection)

### Pagination & Filtering
- All list endpoints must support pagination (cursor-based preferred, offset-based acceptable)
- Support sorting: `?sort=created_at&order=desc`
- Support filtering: `?status=active&created_after=2024-01-01`
- Return pagination metadata in response

### Versioning & Compatibility
- If changing an existing API response shape, consider backward compatibility
- Add new fields freely (additive changes are safe)
- Never remove or rename existing fields without a migration path
- Document breaking changes clearly

### Documentation
- When creating a new endpoint, include: method, path, request body schema, response schema, error codes, auth requirements, and an example curl command
<!-- cappy:end:api-design -->
