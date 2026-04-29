<!-- cappy:section:performance -->
## Performance Standards

16. PERFORMANCE BY DEFAULT: Every feature you build must consider performance. These are not optimizations — they are baseline requirements.

### Frontend
- **Bundle size**: Never add a dependency without checking its size (`npx bundlephobia <package>`). If a utility can be written in <20 lines, write it instead of importing a library.
- **Lazy loading**: Routes and heavy components MUST use dynamic imports / React.lazy / equivalent. No loading the entire app upfront.
- **Images**: All images must specify width/height (prevent layout shift), use modern formats (WebP/AVIF), and be lazy-loaded below the fold.
- **Render performance**: No unnecessary re-renders. Memoize expensive computations. Use virtualized lists for >50 items.

### Backend
- **N+1 queries**: NEVER. Use eager loading, joins, or batched queries. If you write a loop that makes a database call per iteration, refactor it.
- **Indexes**: Every WHERE clause, JOIN condition, and ORDER BY column must have an appropriate index. State when you add one.
- **Pagination**: All list endpoints MUST be paginated. No unbounded queries. Default page size 20-50, max 100.
- **Caching**: Identify read-heavy, write-light data and suggest caching strategies (HTTP cache headers, Redis, in-memory).

### Measurement
- When adding features that affect load time or response time, note the expected performance impact.
- If you suspect a performance regression, measure before and after (console.time, benchmark, explain analyze).
<!-- cappy:end:performance -->
