# Product SDLC Team Template

A complete software development lifecycle in 8 agents with defined handoffs, approval gates, and a review/fix loop.

## The Pipeline

```
 ┌─────────────────────────────────────────────────────────────┐
 │                        USER IDEA                            │
 └────────────────────────────┬────────────────────────────────┘
                              ▼
 ┌─────────────────────────────────────────────────────────────┐
 │  PHASE 1: DISCOVERY                                        │
 │  Agent: Scout                                               │
 │  • Explores existing codebase                               │
 │  • Researches competitive landscape                         │
 │  • Surfaces open questions                                  │
 │  • Produces: Research Brief                                 │
 └────────────────────────────┬────────────────────────────────┘
                              ▼
 ┌─────────────────────────────────────────────────────────────┐
 │  PHASE 2: SPECIFICATION                                     │
 │  Agent: Spec                                                │
 │  • Writes PRD with user stories + acceptance criteria       │
 │  • Defines scope, phasing, success metrics                  │
 │  • Produces: PRD                                            │
 └────────────────────────────┬────────────────────────────────┘
                              ▼
 ╔═════════════════════════════════════════════════════════════╗
 ║              🔒 USER APPROVAL GATE                         ║
 ║  Lead presents PRD to user. Cannot proceed until approved. ║
 ╚════════════════════════════╤════════════════════════════════╝
                              ▼
 ┌─────────────────────────────────────────────────────────────┐
 │  PHASE 3: TECHNICAL DESIGN                                  │
 │  Agent: Architect                                           │
 │  • Architecture decisions, data model, API contracts        │
 │  • Numbered task breakdown tagged [Backend]/[Frontend]      │
 │  • Produces: Design Doc + Task List                         │
 └────────────────────────────┬────────────────────────────────┘
                              ▼
 ╔═════════════════════════════════════════════════════════════╗
 ║              🔒 USER APPROVAL GATE                         ║
 ║  Lead presents design to user. Cannot proceed until ok.    ║
 ╚════════════════════════════╤════════════════════════════════╝
                              ▼
 ┌─────────────────────────────────────────────────────────────┐
 │  PHASE 4: IMPLEMENTATION (parallel)                         │
 │  Agents: Backend-Eng + Frontend-Eng                         │
 │  • Work from architect's task list simultaneously           │
 │  • Write production code + unit tests                       │
 │  • Run type-check + lint after each task                    │
 └──────────┬──────────────────────────────────┬───────────────┘
            └──────────────┬───────────────────┘
                           ▼
 ┌─────────────────────────────────────────────────────────────┐
 │  PHASE 5: REVIEW                                            │
 │  Agent: Reviewer                                            │
 │  • Code quality audit (patterns, naming, duplication)       │
 │  • Security audit (OWASP Top 10)                            │
 │  • Architecture compliance check                            │
 │  • Verdict: PASS or FAIL                                    │
 │                                                             │
 │  ┌─── On FAIL ──→ Back to Engineers with fix tasks ──┐     │
 │  │               (review loop repeats)                │     │
 │  └────────────────────────────────────────────────────┘     │
 └────────────────────────────┬────────────────────────────────┘
                              ▼
 ┌─────────────────────────────────────────────────────────────┐
 │  PHASE 6: VALIDATION                                        │
 │  Agent: QA                                                  │
 │  • Runs ALL Definition of Done gates                        │
 │    (type-check, lint, test, build, coverage)                │
 │  • Traces every acceptance criterion from the PRD           │
 │  • Checks edge cases and integration points                 │
 │  • Verdict: PASS or FAIL                                    │
 │                                                             │
 │  ┌─── On FAIL ──→ Back to Engineers with failures ───┐     │
 │  │               (review + QA loop repeats)           │     │
 │  └────────────────────────────────────────────────────┘     │
 └────────────────────────────┬────────────────────────────────┘
                              ▼
 ┌─────────────────────────────────────────────────────────────┐
 │  COMPLETION                                                 │
 │  Agent: Lead                                                │
 │  • Produces final summary (what was built, tested, shipped) │
 │  • Lists any known limitations or follow-ups                │
 │  • Presents to user for sign-off                            │
 └─────────────────────────────────────────────────────────────┘
```

## Agents

| Agent | Role | Phase | Type |
|-------|------|-------|------|
| **Lead** | Strategic orchestrator — drives pipeline, manages gates | All | team-lead |
| **Scout** | Discovery — codebase exploration, research, questions | 1 | general-purpose |
| **Spec** | Product specification — PRD, user stories, metrics | 2 | general-purpose |
| **Architect** | Technical design — architecture, schema, task breakdown | 3 | general-purpose |
| **Backend-Eng** | Backend implementation — APIs, services, data layer | 4 | general-purpose |
| **Frontend-Eng** | Frontend implementation — UI, state, routing | 4 | general-purpose |
| **Reviewer** | Code quality + security audit | 5 | general-purpose |
| **QA** | Final validation gate — tests, coverage, acceptance criteria | 6 | general-purpose |

## Key Design Decisions

**Why 8 agents and not 27?**
Each agent has a focused context window. 8 agents cover the full SDLC without context decay. Your friend's 27-agent setup has agents for niche domains (geospatial, translations, legal) — if you need those, add them as extensions.

**Why two approval gates?**
Gate 1 (after PRD) catches product direction issues before any code is written. Gate 2 (after design) catches architectural mistakes before implementation begins. These are the two highest-leverage points to course-correct.

**Why a review→fix loop?**
Code review isn't a formality — it's a quality multiplier. If the reviewer finds issues, engineers fix them and the code is re-reviewed. This loop continues until the reviewer approves. Same pattern for QA.

**Why separate Reviewer and QA?**
Reviewer focuses on code quality and security (reading code). QA focuses on correctness and completeness (running code). Different concerns, different expertise.

## Usage

```bash
# Scaffold the team
~/.cappy/scaffold-team.sh product-sdlc \
  --name my-feature \
  --description "Add user dashboard with analytics" \
  --tech "Next.js 15, TypeScript, Supabase, Tailwind"

# Then in Claude Code, the lead drives the pipeline:
# "Build a user dashboard showing activity metrics and recent actions"
```

## Extending

Need more specialized agents? Add them to the team config:
- **i18n-eng** — Internationalization after implementation
- **perf-eng** — Performance optimization and profiling
- **devops-eng** — CI/CD, deployment, infrastructure
- **content-writer** — UI copy, documentation, help text
