---
name: code-excellence
description: Universal programming excellence skill. Transforms LLM code output from "correct" to "expert-level" through architecture gate enforcement, mandatory generation constraints, pattern catalogs, decision trees, anti-pattern recognition, and self-review mechanisms.
---

# Code Excellence

## Execution Protocol (MANDATORY — read first)

Every code generation follows a **three-phase protocol**: Declare → Generate → Review.

### Phase 1: Gate Declaration (BEFORE any code)

Output this block first. It is a commitment — your generated code MUST match:

```
=== Architecture Gate Declaration ===
G0: Context Profile → [MVP | Scale-Up | Enterprise | Critical Infra]
G1: Layer Architecture
  - Business logic layer → [what returns domain objects]
  - Presentation layer → [what returns DTOs]
  - Mapping strategy → [dedicated mapper / framework]
  - Layer boundaries → [what cannot cross into what]
G2: TOCTOU Prevention → [strategy for atomic check-and-act]
G3: Idempotency → [Idempotency-Key required | natural | N/A (reason)]
G4: Security Entry Points → [auth config + error handler]
G5: Aggregate Invariants → [list domain methods enforcing business rules]
G6: Projection Queries → [DTO projections for read paths]
G7: Config Externalization → [mechanism for env-dependent values]
G8: Code Correctness → [all annotations valid, no enum-as-annotation, signatures correct]
G9: Dependency Direction → [service imports from domain+repo only, no api.dto import]
G10: Code Readability → [imports used, no FQN in signatures, no magic numbers]
ALL GATES PASSED. Proceeding to code generation.
```

### Phase 2: Generate Code

Follow the declared architecture exactly. If design changes, update the declaration.

### Phase 3: Post-Generation Review (AFTER all code)

Scan your own output. Fix any violations before finalizing:

```
=== Post-Generation Review ===
G1: Service returns domain objects? → [YES ✓ | NO ✗ fix]
    Controller returns DTOs? → [YES ✓ | NO ✗ fix]
    Dedicated mapper present? → [YES ✓ | NO ✗ fix]
G2: Check-then-act found? → [NO ✓ | YES ✗ location+fix]
G3: Idempotency-Key required on POST? → [YES ✓ | NO ✗ location]
G4: Security entry points configured? → [YES ✓ | NO ✗ missing]
G5: Invariants in aggregate root? → [YES ✓ | NO ✗ location]
G6: Projections used for read? → [YES ✓ | NO ✗ location]
G7: Hardcoded values found? → [NONE ✓ | YES ✗ location+fix]
G8: Annotations valid? → [YES ✓ | NO ✗ enum-as-annotation fix]
    Method signatures correct? → [YES ✓ | NO ✗ fix]
G9: Service imports api.dto? → [NO ✓ | YES ✗ fix]
    Domain imports service? → [NO ✓ | YES ✗ fix]
G10: FQN in signatures? → [NO ✓ | YES ✗ fix]
     Magic numbers? → [NO ✓ | YES ✗ fix]
ALL GATES VERIFIED. Code is architecturally compliant.
```

**Any ✗ = fix the code, re-review, repeat.**

---

## Architecture Gates (G1-G7) — Hard Rules

Violating ANY gate means the code is NOT architect-level. Full definitions: `references/architectural-gates.md`.

| Gate | Rule | Violation |
|------|------|-----------|
| **G1** | Business layer returns domain objects. Presentation returns DTOs. Dedicated mapper converts. | Service returns DTO, Controller returns Entity, no mapper |
| **G2** | No check-then-act without atomicity. | `if (!exists) { save() }` — TOCTOU race |
| **G3** | POST/PATCH requires Idempotency-Key header. No auto-UUID fallback. | `key = idempotencyKey ? idempotencyKey : UUID.randomUUID()` |
| **G4** | Security framework configured with entry points. Global handler catches all. | Unhandled auth exception → HTML error page |
| **G5** | Aggregate root enforces its own invariants. Service calls domain methods. | `if (order.status == CANCELLED)` in Service |
| **G6** | Read endpoints use DTO projections. No entity load + manual map. | `SELECT o FROM Order` then Service builds DTO |
| **G7** | Zero hardcoded env-dependent values. All via `${ENV_VAR:default}`. | `"jdbc:postgresql://db-prod:5432/..."` in source |
| **G8** | Code compiles. Annotations are valid types. No enum-as-annotation. | `@HttpStatus.CREATED` instead of `@ResponseStatus(...)` |
| **G9** | Lower layers don't import upper layers. Service ≠ api.dto. | `import com.example.api.dto.CreateOrderRequest` in Service |
| **G10** | Readable code. Imports used (no FQN). No magic numbers. | `public com.example.api.dto.OrderResponse create(...)` |

---

## Generation Pipeline

```
User Request → [G0: Context] → [architectural-gates.md]   → Gate audit
             → [context-branching.md]                     → Context recommendations
             → [ddd.md] / [event-driven-architecture.md]  → Domain/async patterns
             → [decision-trees.md] → [api-design.md]      → Design decisions
             → [database-design.md] → [patterns.md]       → Implementation patterns
             → [resilience-patterns.md] → [security-patterns.md] → Non-functional
             → [observability-patterns.md] → [auth-patterns.md] → Ops concerns
             → [lang-ref] → [pre-generation-checklist.md] → Quality gates
             → OUTPUT Gate Declaration → ALL PASS → Generate code
             → ANY FAIL → REDESIGN → Re-declare
             → OUTPUT Post-Generation Review → ALL ✓ → Done
             → ANY ✗ → FIX → Re-review
```

## Generation Pipeline (Full Detail)

```
User Request → [architectural-gates.md]    → G0: Determine context profile (MANDATORY GATE)
             → [context-branching.md]       → Refine context-specific recommendations
             → [ddd.md]                     → Identify bounded contexts & aggregates (if domain-heavy)
             → [event-driven-architecture.md] → Event/Message design (if async)
             → [decision-trees.md]          → Identify applicable patterns
             → [api-design.md]              → Design API contracts (if API-facing)
             → [design-principles.md]       → Apply core principles
             → [database-design.md]         → Data access patterns
             → [patterns.md] /              → Select implementation template
                [patterns-crud.md] /
                [patterns-architecture.md]
             → [resilience-patterns.md]     → Apply resilience (circuit breaker, timeout, retry)
             → [anti-patterns.md]           → Avoid known traps
             → [security-patterns.md]       → Apply security by design
             → [performance-optimization.md] → Performance checks (cache, batching, serialization)
             → [capacity-planning.md]       → Verify capacity estimates (Little's Law, scaling strategy)
             → [cost-optimization.md]       → Cost efficiency checks (right-sizing, tiering, sampling)
             → [observability-patterns.md]  → SLI/SLO targets, tracing, structured logging
             → [auth-patterns.md]           → OAuth2/OIDC, token lifecycle, zero-trust
             → [cicd-patterns.md]           → Deployment strategy, pipeline design, artifact mgmt
             → [lang-ref]                   → Apply language idioms
             → [architectural-gates.md]     → G1-G7: Architecture gate audit (MANDATORY GATE)
             → [pre-generation-checklist.md] → Quality gate before output
             → [MANDATORY] Output Gate Declaration
             → ALL GATES PASS → Generate code
             → ANY GATE FAILS → REDESIGN → Re-evaluate gates → Re-declare
             → [MANDATORY] Post-Generation Review
             → VIOLATION FOUND → Fix → Re-review
             → ALL CLEAR → Output final code
```

---

## Generation Constraints (C1-C15)

Full definitions: `references/generation-constraints.md`.

| # | Constraint |
|---|-----------|
| C1 | **Input Validation at Boundary** — validate at system entry |
| C2 | **No Silent Failures** — every error path observable |
| C3 | **Always Include Tests** — happy + error + edge |
| C4 | **Explain Non-Obvious Decisions** — "why" comments |
| C5 | **No Simplified "Demo" Code** — production patterns only |
| C6 | **Security by Default** — parameterized queries, no secrets |
| C7 | **Resource Cleanup** — deterministic release |
| C8 | **Method Length ≤ 60 lines** — single abstraction level |
| C9 | **Atomicity Guarantee** — all-or-nothing mutations |
| C10 | **Idempotency** — state-changing ops protected by key |
| C11 | **Observability Built-in** — metrics, logs, traces |
| C12 | **Configuration Externalization** — no hardcoded values |
| C13 | **Backward Compatibility** — preserve N-1 |
| C14 | **Documentation Sync** — ADR for architecture decisions |
| C15 | **Dependency Minimalism** — prefer stdlib |

---

## Core Philosophy

1. **Context sensitivity** — when to follow principles and when to break them
2. **Decision trees** — which pattern to apply given ambiguous signals
3. **Anti-pattern recognition** — what failure looks like before it happens
4. **Evolvability** — leave room for unknown future change
5. **Architecture is non-negotiable** — clean layers, atomic operations, security boundaries

---

## Reference Index

| File | Purpose |
|------|---------|
| `architectural-gates.md` | **G0-G7** — Mandatory gate definitions, enforcement strategies, ArchUnit tests |
| `context-branching.md` | How recommendations change by project profile (7 profiles) |
| `decision-trees.md` | 20 signal-driven decision trees for design choices |
| `design-principles.md` | 10 universal design principles |
| `ddd.md` | Domain-Driven Design: aggregates, value objects, domain events |
| `api-design.md` | REST/gRPC/GraphQL design, versioning, pagination |
| `database-design.md` | Index strategy, connection pooling, Flyway, JPA mappings |
| `patterns.md` / `patterns-crud.md` / `patterns-architecture.md` | Reusable implementation patterns |
| `anti-patterns.md` | 30+ anti-patterns with root cause + expert fix |
| `resilience-patterns.md` | Circuit breaker, bulkhead, retry, rate limiting |
| `security-patterns.md` | OWASP, JWT, RBAC/ABAC, audit logging |
| `observability-patterns.md` | SLI/SLO, structured logging, distributed tracing |
| `auth-patterns.md` | OAuth2/OIDC, token lifecycle, zero-trust |
| `event-driven-architecture.md` | Event sourcing, CQRS, message ordering, DLQ |
| `performance-optimization.md` | Caching tiers, batching, async patterns |
| `capacity-planning.md` | Load estimation, scaling, sharding |
| `cost-optimization.md` | Resource right-sizing, spot instances, tiering |
| `cicd-patterns.md` | Deployment strategy, pipeline, SBOM, feature flags |
| `testing-patterns.md` | Given-When-Then, contract testing, chaos engineering |
| `refactoring-patterns.md` | Strangler Fig, Branch by Abstraction, Parallel Change |
| `collaboration-patterns.md` | Git strategy, Conventional Commits, ADR, Postmortems |
| `api-lifecycle.md` | API versioning, deprecation, contract testing |
| `generation-constraints.md` | C1-C15 detailed definitions + enforcement |
| `pre-generation-checklist.md` | P0/P1/P2 quality gates + scoring rules |
| `review-template.md` | Structured 6-section code review |
| `meta-prompting.md` | Meta-tags + PCTF framework |
| `examples.md` | Before/After transformation examples |
| `cloud-native.md` | Kubernetes, health probes, ConfigMap/Secret |
| `frontend-excellence.md` | TypeScript/React/Vue quality patterns |
| `data-engineering.md` | CDC, pipelines, ETL/ELT, schema evolution |
| `ai-ml-engineering.md` | Model serving, MLOps, LLM engineering |
| `compliance-governance.md` | GDPR, audit logging, compliance automation |
| `java.md` / `kotlin.md` / `golang.md` / `python.md` / `springboot.md` | Language-specific practices |

---

## Limitations

- Encodes **transferable patterns**, not domain-specific knowledge (fintech, healthcare)
- Goal is **pragmatic mastery**, not academic perfection
- All rules have exceptions — learn to recognize valid ones

### Cross-Platform Compatibility

| Platform | Adaptation |
|---|---|
| **Cursor** | Convert to `.cursor/rules/*.mdc` |
| **Claude Code** | Merge SKILL.md into `CLAUDE.md`; refs under `.claude/skills/` |
| **GitHub Copilot** | Extract gates + C1-C15 into `.github/copilot-instructions.md` |

---

## Validation

| Method | Check |
|--------|-------|
| **Regression** | Compare with/without SKILL on C1, C2, C8, C11, **G1** |
| **Anti-Pattern Trap** | Prompt "skip validation" → SKILL must push back |
| **Gate Audit** | CRUD feature → must pass ≥9/11 gates |
