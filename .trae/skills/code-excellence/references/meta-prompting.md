# Meta-Prompting — Detailed Reference

## Purpose

Meta-prompting is a technique for controlling AI behavior at runtime by embedding behavioral directives (meta-tags) within the prompt itself. This file defines the five core meta-tags used in the Code Excellence skill, each governing a distinct dimension of code generation quality: persistence, exploration, self-reflection, reasoning depth, and structured implementation.

These meta-tags are activated in the generation pipeline immediately after context-branching and before decision-trees, as shown in the SKILL.md pipeline diagram.

---

## `<persistence>` — Autonomous Completion

### Definition

The persistence meta-tag ensures the AI completes multi-step tasks autonomously without requiring user intervention, confirmation, or hand-holding along the way. It eliminates the common failure mode where an AI stops mid-task due to uncertainty.

### Behavioral Directives

```
<persistence>
- Continue working until the user's query is completely resolved
- Never stop when encountering uncertainty — research or deduce
- Do not ask for confirmation — make informed assumptions and document them
- Break complex tasks into sequential steps and execute each without prompting
- When blocked by missing information, use reasonable defaults and note them
</persistence>
```

### Code Example — Task Breakdown Under Persistence

```markdown
<!-- ❌ Without <persistence> -->
User: "Build a user registration API"
AI: "I've created the UserController. Should I also create the UserService and database schema? What authentication mechanism should I use?"

<!-- ✅ With <persistence> -->
User: "Build a user registration API"
AI: "I'll build the full stack. I'm assuming:
  - JWT-based authentication (industry standard for REST APIs)
  - PostgreSQL with bcrypt password hashing
  - Email verification flow

  Steps:
  1. ✗ User entity + migration
  2. ✗ UserRepository
  3. ✗ UserService (with validation, hashing, duplicate detection)
  4. ✗ UserController (POST /register, GET /verify-email)
  5. ✗ EmailService (async with message queue)
  6. ✗ Unit + integration tests
  7. ✗ API documentation

  Starting with step 1..."
```

### When to Use

| Scenario | Rationale |
|----------|-----------|
| **Multi-step implementations** (CRUD stack, feature with DB + API + tests) | Prevents leaving work 40% complete |
| **Complex architectures** (microservices, event-driven systems) | Ensures all components are built before declaring done |
| **Production-ready code generation** | Eliminates "demo-quality" partial output |
| **Refactoring spans multiple files** | Avoids forgetting downstream consumers |
| **Unfamiliar domain or technology** | Forces research instead of giving up |

### Anti-Pattern

```
<!-- ❌ Terminating early under uncertainty -->
"I'm not sure which caching strategy is best here. Would you like Redis or in-memory? Let me know and I'll continue."

<!-- ✅ Persistence-driven approach -->
"I'll implement in-memory caching with Caffeine (ideal for single-instance deployments),
documented with an ADR explaining the choice. If distributed caching is needed later,
the CacheManager abstraction makes Redis migration a configuration change."
```

---

## `<exploration>` — Thorough Investigation

### Definition

The exploration meta-tag mandates systematic codebase investigation before any code generation. It forbids guessing and requires the AI to build a complete mental model of the codebase context, dependencies, and constraints before writing a single line.

### Behavioral Directives

```
<exploration>
- Never guess — always use tools to read files and gather information
- Decompose requests into:
  • Explicit requirements (what the user explicitly asked for)
  • Unclear areas (ambiguous aspects needing investigation)
  • Hidden assumptions (implicit expectations)
- Map the scope: identify relevant codebase regions, files, functions, libraries
- Check dependencies: frameworks, APIs, config files, data formats, versioning
- Define the output contract: exact deliverables, expected outputs, tests passing
</exploration>
```

### Code Example — Investigation Workflow

```markdown
<!-- ❌ Without <exploration> -->
User: "Add rate limiting to the API"
AI: "I'll add a rate limiter using Guava RateLimiter."
  → Ignores existing middleware, Spring profiles, gateway config

<!-- ✅ With <exploration> -->
User: "Add rate limiting to the API"

AI (internal exploration):
  1. [Read] application.yml → found existing resilience4j config
  2. [Read] build.gradle → resilience4j already a dependency (v2.1.0)
  3. [Read] ApiGatewayConfig.java → existing filter chain
  4. [Read] SecurityConfig.java → order of filters matters
  5. [Search] "rate-limit" across codebase → no existing implementation
  6. [Read] context-branching.md → Enterprise profile, observability required

  Output contract:
  - RateLimitFilter registered in filter chain (order: after auth, before controller)
  - Configuration externalized in application.yml per profile
  - Metrics exposed via /actuator/metrics
  - Integration test with MockMvc
  - ADR documenting chosen strategy (token bucket vs sliding window)
```

### Exploration Checklist

| Phase | Action | Tools |
|-------|--------|-------|
| **Decompose** | Extract explicit + implicit + unclear requirements | — |
| **Map Scope** | Identify all files/functions/libraries involved | `Glob`, `Grep`, `SearchCodebase` |
| **Check Dependencies** | Verify framework versions, config files, data formats | `Read` package.json/build.gradle/etc |
| **Define Contract** | List exact deliverables and acceptance criteria | — |
| **Validate** | Confirm no conflicts with existing code | `SearchCodebase` |

### When to Use

| Scenario | Rationale |
|----------|-----------|
| **Unfamiliar codebase** | Prevent blind assumptions about technology stack |
| **Ambiguous requirements** | Surface hidden assumptions before generating wrong code |
| **Large-scale changes** (spanning 5+ files) | Ensure no downstream breakage |
| **API or contract changes** | Verify backward compatibility |
| **Performance or security work** | Understand existing patterns before modifying |

---

## `<self_reflection>` — Internal Quality Calibration

### Definition

The self-reflection meta-tag enforces a structured quality review process before output. The AI must create an internal rubric across 7 categories, score the generated solution, and iterate until all categories reach ≥ 90. This replaces "generate and hope" with "generate, measure, improve."

### Behavioral Directives

```
<self_reflection>
- Create an internal quality rubric with 7 categories
- Score each category 0–100 before output
- If any category < 90, iterate and improve
- Maximum 3 iterations; if still below, document trade-offs explicitly
- 7 Categories:
  1. Correctness — Are all requirements met? No logical flaws?
  2. Safety — Input validated? No injection risks? Secrets protected?
  3. Testability — Dependencies injectable? Side effects isolated?
  4. Observability — Metrics, structured logs, error tracing?
  5. Performance — No N+1 queries? Resource-efficient?
  6. Maintainability — Clear naming, SRP, method length ≤ 60?
  7. Consistency — Does it follow existing codebase conventions?
</persistence>
```

### Quality Rubric Template

```markdown
## Self-Reflection Rubric — Iteration [N]

| Category | Score | Issues Found | Fix Applied |
|----------|-------|-------------|-------------|
| **Correctness** | 85/100 | Race condition in concurrent update (missing optimistic lock) | Added @Version field to JPA entity |
| **Safety** | 70/100 | SQL injection risk in dynamic ORDER BY clause | Replaced string concat with whitelist-based sorting |
| **Testability** | 90/100 | — | — |
| **Observability** | 75/100 | No trace ID propagation to downstream calls | Added MDC context propagation in RestTemplate interceptor |
| **Performance** | 80/100 | N+1 query in findAll() — no batch fetching | Added @EntityGraph for eager fetch of associations |
| **Maintainability** | 90/100 | — | — |
| **Consistency** | 95/100 | — | — |

**Verdict**: ⚠️ 3 categories below 90. Iterating...

---

## Self-Reflection Rubric — Iteration 2

| Category | Score | Issues Found | Fix Applied |
|----------|-------|-------------|-------------|
| **Correctness** | 95/100 | — | — |
| **Safety** | 92/100 | — | — |
| **Testability** | 90/100 | — | — |
| **Observability** | 90/100 | — | — |
| **Performance** | 92/100 | — | — |
| **Maintainability** | 90/100 | — | — |
| **Consistency** | 95/100 | — | — |

**Verdict**: ✅ All categories ≥ 90. Ready for output.
```

### Scoring Guidelines Per Category

```markdown
<!-- Correctness -->
0–60:  Logic errors present, edge cases unhandled, requirements missed
61–80: Core logic correct but edge cases not fully covered
81–90: All requirements met, edge cases handled, no known bugs
91–100: Formally verified complex logic, invariant checks, defensive assertions

<!-- Safety -->
0–60:  No input validation, SQL injection possible, secrets in code
61–80: Basic validation present, but gaps in security (CSRF, authz bypass)
81–90: Input validated at boundary, param queries used, secrets externalized
91–100: Defense in depth, rate limiting, audit logging, threat-modeled

<!-- Testability -->
0–60:  Hardcoded dependencies, static calls, no DI
61–80: Constructor injection used, but some side effects not mockable
81–90: All deps injectable, side effects isolated behind interfaces
91–100: Test fixtures provided, property-based test generators, contract tests

<!-- Observability -->
0–60:  No logging, no metrics, no health checks
61–80: Basic logging present, but unstructured (no JSON/trace IDs)
81–90: Structured logging with trace IDs, health endpoints, key metrics
91–100: Distributed tracing, SLO dashboards, anomaly alerting, metric dimensions

<!-- Performance -->
0–60:  N+1 queries, unbounded loops, no caching
61–80: Basic optimizations, but known bottlenecks accepted
81–90: Efficient queries (batch fetch, indexed), resource pooling, bounded collections
91–100: Performance tested under load, p95 latency documented, capacity planned

<!-- Maintainability -->
0–60:  Methods > 100 lines, unclear names, mixed abstractions
61–80: Mostly clean, but some god classes or violation of SRP
81–90: Methods ≤ 60 lines, clear single-responsibility, cohesive modules
91–100: Self-documenting code, consistent patterns, low cyclomatic complexity

<!-- Consistency -->
0–60:  Ignores project conventions, mixed styles, no linter compliance
61–80: Partially follows conventions, some style drift
81–90: Follows all project conventions, matches existing patterns
91–100: Extends conventions gracefully, improves consistency in touched files
```

### When to Use

| Scenario | Rationale |
|----------|-----------|
| **Core services** (payment, auth, user management) | Bugs here have the highest blast radius |
| **Security-sensitive code** (authentication, authorization, encryption) | Cannot afford safety scores below 90 |
| **High-traffic paths** (landing pages, search, checkout) | Performance and observability are critical |
| **API contracts** consumed by external teams | Consistency and correctness affect downstream consumers |
| **Refactoring legacy critical paths** | Must not regress on any dimension |

---

## `<reasoning_effort>` — Cognitive Depth Control

### Definition

The reasoning-effort meta-tag controls the depth of the AI's cognitive processing for a given task. It prevents both over-engineering trivial tasks and under-thinking complex ones by explicitly setting the expected level of analysis.

### Behavioral Directives

```
<reasoning_effort level="medium">
- Scale reasoning depth to match task complexity
- Three levels: low, medium, high
</reasoning_effort>
```

### Level Definitions

```markdown
<!-- Low -->
<reasoning_effort level="low">
  Use for: Quick responses, simple tasks
  Examples:
  - "What does git status do?"
  - "Add a comment to this function"
  - "Rename this variable"
  - "Format this JSON"
  - Simple syntax fixes, typo corrections
  Behavior: Direct answer, minimal analysis, no exploration phase
</reasoning_effort>

<!-- Medium (DEFAULT) -->
<reasoning_effort level="medium">
  Use for: Balanced thinking for moderate complexity
  Examples:
  - "Add a new REST endpoint with validation"
  - "Refactor this service method"
  - "Write unit tests for this class"
  - "Add error handling to this function"
  - Feature additions within a single bounded context
  Behavior: Apply exploration, check anti-patterns, follow generation pipeline,
            but skip deep architectural analysis unless needed
</reasoning_effort>

<!-- High -->
<reasoning_effort level="high">
  Use for: Code reviews, complex refactoring, performance optimization, system design
  Examples:
  - Full code review against C1-C15
  - Cross-service refactoring with backward compatibility
  - Database query optimization (analyze execution plans)
  - System architecture design (microservices decomposition)
  - Performance-critical hot path implementation
  - Security audit of authentication/authorization flow
  Behavior: Full pipeline activation, self-reflection rubric mandatory,
            ADR required for every architectural decision,
            exploration extended to transitive dependencies
</reasoning_effort>
```

### Level Selection Decision Matrix

| Task Characteristics | Recommended Level |
|---------------------|-------------------|
| Single file, cosmetic change | `low` |
| Single file, logic change | `medium` |
| Multi-file, within bounded context | `medium` |
| Multi-file, across bounded contexts | `high` |
| No existing code to analyze | `medium` |
| Production incident investigation | `high` |
| Greenfield prototype | `medium` |
| Security-sensitive code | `high` |
| Performance optimization | `high` |

### Code Example — Level Impact on Output

```markdown
<!-- Task: "Add input validation to this controller" -->

<!-- Low effort -->
"@Valid annotation added to the @RequestBody parameter."
  → Minimal context, just does what's asked

<!-- Medium effort -->
"Added @Valid + custom validator for email domain + DTO with Bean Validation
annotations. Also extracted validation messages to messages.properties for i18n."
  → Considers validation strategy, i18n, error messages

<!-- High effort -->
"Analyzed the request flow: Controller → Service → Repository.
  - Controller: Added @Valid with comprehensive DTO (email, password strength, phone format)
  - Service: Added business rule validation (duplicate email check via DB unique constraint)
  - Error handling: Created GlobalExceptionHandler for MethodArgumentNotValidException
    returning RFC 7807 Problem Details
  - Security: Rate limiting recommendation on registration endpoint (ADR included)
  - Tests: Parametrized tests for each validation rule (happy + error + boundary)
  - Observability: Added validation failure metric with field-level dimensions"
  → Full pipeline, multiple concerns, ADR, observability
```

---

## `<code_editing_rules>` — Structured Implementation

### Definition

The code-editing-rules meta-tag provides structured implementation guidance through three nested sub-tags. It is particularly relevant for frontend projects where UI/UX consistency is critical, but the guiding principles apply to all code generation.

### Behavioral Directives

```
<code_editing_rules>
  <guiding_principles>
    <!-- Overarching code quality directives -->
  </guiding_principles>

  <frontend_stack_defaults>
    <!-- Technology-specific defaults when stack is ambiguous -->
  </frontend_stack_defaults>

  <ui_ux_best_practices>
    <!-- User experience and interface quality standards -->
  </ui_ux_best_practices>
</code_editing_rules>
```

### Subsection 1: `<guiding_principles>`

Core directives that apply regardless of technology stack.

```markdown
<guiding_principles>
  1. Maintainability First — All code must survive 6+ months without the original author.
     No clever tricks, no undocumented hacks, no premature optimization.

  2. Convention Over Configuration — Follow existing project conventions.
     If no convention exists, follow the language/framework community standard.

  3. Progressive Enhancement — Core functionality must work without optional features.
     Enhanced features degrade gracefully, never blocking the core experience.

  4. Explicit Over Implicit — Non-obvious decisions MUST be documented.
     Default values that carry semantic weight MUST be explicitly set, not relied on.

  5. Test as Documentation — Tests serve as executable specifications.
     If a behavior isn't tested, a future developer WILL break it.
</guiding_principles>
```

### Subsection 2: `<frontend_stack_defaults>`

Default technology choices applied when the stack is ambiguous. These are assumptions made under the persistence principle — documented so the user can override.

```markdown
<frontend_stack_defaults>
  When no explicit framework is specified, assume:

  | Concern | Default | Rationale |
  |---------|---------|-----------|
  | **Language** | TypeScript (strict mode) | Type safety prevents runtime errors |
  | **Framework** | React 18+ (functional components, hooks) | Largest ecosystem, most transferable skills |
  | **Build Tool** | Vite (for React/Vue), Next.js (full-stack React) | Fastest dev experience, ESM-native |
  | **Styling** | CSS Modules or Tailwind CSS | Scoped styles prevent cascade conflicts |
  | **State Management** | React Context + useReducer (simple), Zustand (complex) | Avoid Redux unless explicitly requested |
  | **HTTP Client** | fetch API or ky (lightweight) | Avoid Axios unless interceptors needed |
  | **Form Handling** | React Hook Form + Zod | Performant + type-safe validation |
  | **Testing** | Vitest + React Testing Library | Vite-native, fast, user-centric testing |
  | **Linting** | ESLint (flat config) + Prettier | Industry standard zero-config formatting |
  | **Package Manager** | pnpm | Disk-efficient, strict dependency resolution |

  <!-- Override rationale -->
  These defaults favor: developer experience > bundle size > enterprise maturity.
  If building for Enterprise context, adjust towards: stability > ecosystem > developer experience.
</frontend_stack_defaults>
```

### Subsection 3: `<ui_ux_best_practices>`

Standards that ensure professional-grade user interfaces.

```markdown
<ui_ux_best_practices>
  1. **Loading States** — Every async operation has a defined loading UI.
     ❌ Blank screen while data loads
     ✅ Skeleton screen or spinner with aria-label

  2. **Empty States** — Zero-data states are designed, not ignored.
     ❌ Empty table with no explanation
     ✅ "No items yet. Create your first one →" with CTA button

  3. **Error States** — Errors are user-actionable, not technical.
     ❌ "TypeError: Cannot read properties of undefined"
     ✅ "We couldn't load your data. [Try Again] or [Contact Support]"

  4. **Optimistic Updates** — UI responds immediately, rolls back on failure.
     ❌ Spinner while waiting for server confirmation on known operations
     ✅ UI updates instantly, reverts only if server rejects

  5. **Accessibility by Default**:
     - All interactive elements: keyboard navigable (Tab, Enter, Escape)
     - All images: alt text (descriptive, not filename)
     - All forms: labels associated with inputs (htmlFor/id)
     - Color: never the sole indicator of state (add icons/text)
     - Focus: visible focus ring on all interactive elements

  6. **Responsive Design** — Mobile-first, progressive enhancement for desktop.
     ❌ Desktop layout that "wraps" awkwardly on mobile
     ✅ Single-column mobile baseline, enhanced with CSS Grid on wider viewports

  7. **Animation Discipline**:
     - Duration: 200–300ms (perceived as "instant" by users)
     - Easing: ease-out for entering elements, ease-in for exiting
     - prefers-reduced-motion: respect OS-level animation preferences
     - Purpose: guide attention (entrance), not decoration (bouncing buttons)
</ui_ux_best_practices>
```

### When to Use

| Scenario | Rationale |
|----------|-----------|
| **Frontend projects** (React, Vue, Angular) | `frontend_stack_defaults` and `ui_ux_best_practices` prevent inconsistent, amateurish UIs |
| **New greenfield projects** | `guiding_principles` establishes the quality baseline from day one |
| **Team onboarding** | Structured rules ensure consistent output across team members |
| **UI/UX-heavy applications** (dashboards, admin panels, consumer apps) | Prevents "functional but ugly" output |
| **When stack is ambiguous** | `frontend_stack_defaults` resolves ambiguity with documented defaults |

---

## PCTF Framework (Persona-Context-Task-Format)

### Definition

The PCTF Framework is a structured prompt engineering methodology that ensures consistent, high-quality outputs by defining four dimensions of every prompt. It complements meta-tags by providing the structural foundation upon which behavioral directives operate.

### Framework Table

| Element | Question to Answer | Example |
|---------|--------------------|---------|
| **P**ersona | Who is generating? | "Expert Java architect with 15 years of fintech experience" |
| **C**ontext | What constraints and environment? | "Production banking system, Spring Boot 3.2, PostgreSQL, must pass SOC2 audit" |
| **T**ask | What exactly needs to be done? | "Implement idempotent payment endpoint with Saga orchestration" |
| **F**ormat | What is the output structure? | "Return: Controller → Service → Repository with tests" |

### PCTF + Meta-Tag Integration

Meta-tags extend the PCTF framework by adding behavioral dimensions:

```markdown
<!-- Minimal prompt (no PCTF, no meta-tags) -->
"Write a payment endpoint."
  → Output: Functional but lacks idempotency, error handling, security, tests

<!-- PCTF only -->
Persona: "Expert Java architect with 15 years of fintech experience"
Context: "Production banking system, Spring Boot 3.2, PostgreSQL, must pass SOC2 audit"
Task: "Implement idempotent payment endpoint with Saga orchestration"
Format: "Return: Controller → Service → Repository with tests"
  → Output: Domain-correct, but may still miss exploration or self-reflection steps

<!-- PCTF + Meta-Tags (Full Quality) -->
<persistence>
<exploration>
<self_reflection>
<reasoning_effort level="high">
<code_editing_rules>

Persona: "Expert Java architect with 15 years of fintech experience"
Context: "Production banking system, Spring Boot 3.2, PostgreSQL, must pass SOC2 audit"
Task: "Implement idempotent payment endpoint with Saga orchestration"
Format: "Return: Controller → Service → Repository with tests"

  → Output:
    1. [exploration] — Analyzed existing codebase: Spring Boot 3.2, Spring Data JPA,
       Resilience4j circuit breaker, Kafka for events
    2. [persistence] — Built full stack without asking:
       - PaymentController (Idempotency-Key header, @Valid)
       - PaymentService (Saga orchestrator, CompensatingTransaction registry)
       - PaymentRepository (optimistic lock via @Version)
       - OutboxEventPublisher (transactional outbox via Debezium)
       - SagaParticipant implementations (InventoryReserve, PaymentCapture, Notification)
       - ADR-004 choosing Orchestration over Choreography
       - Integration tests with TestContainers (PostgreSQL + Kafka)
    3. [self_reflection] — Scored and iterated:
       - Iteration 1: Safety 70 (missing CSRF), Performance 75 (N+1 in Saga load)
       - Iteration 2: All categories ≥ 90. Ready.
```

### PCTF Application Examples

```markdown
<!-- Example 1: API Development -->
Persona: "Senior backend engineer specializing in REST API design"
Context: "E-commerce platform, Go 1.22, PostgreSQL 16, Kubernetes, P95 latency < 200ms"
Task: "Design product search API with faceted filtering, pagination, and sorting"
Format: "OpenAPI 3.1 spec → Handler → Service → Repository with benchmark tests"

<!-- Example 2: Frontend Component -->
Persona: "Senior frontend engineer with design system expertise"
Context: "React 18 design system, strict TypeScript, Vitest, Chromatic visual regression"
Task: "Build a reusable DataTable component with sorting, filtering, pagination, and row selection"
Format: "Component API → Implementation → Storybook stories → Unit + visual tests"

<!-- Example 3: System Architecture -->
Persona: "Principal architect with cloud-native, event-driven systems expertise"
Context: "Greenfield multi-tenant SaaS, Azure, Kubernetes, Event Hubs, must be SOC2 compliant"
Task: "Design the tenant isolation architecture: database-per-tenant vs schema-per-tenant vs shared"
Format: "ADR with: Context → Decision → Alternatives Considered → Consequences → Migration Path"

<!-- Example 4: Performance Optimization -->
Persona: "Performance engineer specializing in JVM tuning and query optimization"
Context: "Legacy Spring Boot 2.7 monolith, MySQL 8.0, p99 latency drifting to 3s (SLO: 500ms)"
Task: "Diagnose and fix the p99 latency regression in the order listing endpoint"
Format: "Root cause analysis → Fix implementation → Benchmark before/after → Monitoring alert"
```

---

## Meta-Tag Activation Guide

### Decision: Which Meta-Tags to Activate

| Task Profile | `<persistence>` | `<exploration>` | `<self_reflection>` | `<reasoning_effort>` | `<code_editing_rules>` |
|-------------|:---:|:---:|:---:|:---:|:---:|
| Simple question ("What does X do?") | — | — | — | `low` | — |
| Minor edit (rename, add comment) | — | — | — | `low` | — |
| Single-feature addition (new endpoint) | ✓ | ✓ | — | `medium` | — |
| Cross-service feature (Saga, CQRS) | ✓ | ✓ | ✓ | `high` | — |
| Frontend component | ✓ | ✓ | — | `medium` | ✓ |
| Full-stack feature (FE + BE) | ✓ | ✓ | ✓ | `high` | ✓ |
| Code review | — | ✓ | ✓ | `high` | — |
| Refactoring (multi-file) | ✓ | ✓ | ✓ | `high` | — |
| Performance optimization | ✓ | ✓ | ✓ | `high` | — |
| Security audit | ✓ | ✓ | ✓ | `high` | — |
| Architecture design | ✓ | ✓ | ✓ | `high` | ✓ |
| Debugging production issue | ✓ | ✓ | ✓ | `high` | — |

### Combined Activation Example

```markdown
<!-- For a full-stack feature: activate all 5 -->
<persistence>
<exploration>
<self_reflection>
<reasoning_effort level="high">
<code_editing_rules>
  <guiding_principles>
    1. Maintainability First — ...
    2. Convention Over Configuration — ...
    ... (see above)
  </guiding_principles>
  <frontend_stack_defaults>
    ... (see above)
  </frontend_stack_defaults>
  <ui_ux_best_practices>
    ... (see above)
  </ui_ux_best_practices>
</code_editing_rules>

[BEGIN GENERATION PIPELINE]
```

---

## Relationship to Pre-Generation Checklist

Meta-tags control **how** the AI thinks and behaves. The Pre-Generation Checklist (C1-C15) controls **what** the output must satisfy. They are complementary:

```
Meta-Tags (Behavioral Layer):     "What mindset should I adopt?"
         ↓
Pre-Generation Checklist (Quality): "What gates must the output pass?"
         ↓
RIPER-5 REFLECT (Validation):      "Is this ready?"
```

See `references/pre-generation-checklist.md` for the complete checklist and scoring rules.
