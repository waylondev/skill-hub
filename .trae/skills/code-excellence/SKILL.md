---
name: code-excellence
description: Universal programming excellence skill. Transforms LLM code output from "correct" to "expert-level" through pattern catalogs, decision trees, anti-pattern recognition, architecture gate enforcement, and mandatory generation constraints that prevent simplified "just works" code.
---

# Code Excellence

## How LLMs Should Use This Skill

This is not a principles document to read passively. It is an **operating system for code generation**.
Use it as follows:

### Generation Pipeline

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
             → ALL GATES PASS → Generate code
             → ANY GATE FAILS → REDESIGN → Re-evaluate gates
```

### Architecture Gate Enforcement

**CRITICAL**: Before generating ANY code, ALL 7 gates in [architectural-gates.md] MUST pass.
This is not optional — it is the primary mechanism preventing AI from generating sub-architectural code.

| Gate | Name | Failure Consequence |
|------|------|-------------------|
| G0 | Context Profile | Code mismatched to project stage (over-engineered MVP or under-engineered production) |
| G1 | Layer Architecture | Service returns DTOs (violates clean architecture), Entity leaks to Controller, business logic in wrong layer |
| G2 | TOCTOU Prevention | Race conditions in concurrent creation — duplicates, overbooking, data corruption |
| G3 | Idempotency | Double charges, duplicate orders, non-idempotent retries |
| G4 | Security Entry Points | HTML error pages on API, leaked stack traces, security exceptions unhandled |
| G5 | Aggregate Invariants | Anemic domain model, business logic scattered across Service, invariants violated |
| G6 | Projection Queries | N+1 queries, loading full entity graphs for list endpoints, wasted memory/GC |
| G7 | Config Externalization | Hardcoded URLs/credentials, "works in dev breaks in prod" |

**If any gate fails, AI MUST**:
1. Stop code generation immediately
2. Identify which gate failed and why
3. Redesign the architecture to satisfy the gate
4. Re-evaluate ALL gates
5. Only generate when ALL gates pass

### Review Pipeline

```
Generated Code → [review-template.md]       → Structured review
              → [architectural-gates.md]    → Re-verify G1-G7 on generated code
              → [anti-patterns.md]          → Scan for anti-patterns
              → [decision-trees.md]         → Verify decisions match context
              → [security-patterns.md]      → Security review
              → [auth-patterns.md]          → Auth flow correctness, token lifecycle
              → [resilience-patterns.md]    → Verify timeout/retry/circuit-breaker configs
              → [observability-patterns.md] → Verify SLI/SLO alignment, tracing coverage
              → [collaboration-patterns.md] → Verify review checklist (C1-C15 alignment)
              → [RIPER-5 REFLECT]           → Final validation
              → Flag issues or approve
```

### Refactoring Pipeline

```
Legacy/Target Code → [anti-patterns.md]           → Identify root cause
                   → [decision-trees.md]          → Choose target pattern
                   → [architectural-gates.md]     → Define target architecture
                   → [patterns-architecture.md]   → Architecture restructuring
                   → [refactoring-patterns.md]    → Apply safe migration pattern:
                       Strangler Fig / Branch by Abstraction / Feature Toggle /
                       Parallel Change (Expand-Contract) / Dark Launching
```

### Debugging Pipeline

```
Production Issue → [anti-patterns.md]     → Symptom → Root Cause matching
                → [security-patterns.md]  → Rule out security incidents first
                → [resilience-patterns.md] → Check circuit breaker state, timeout configs, retry storms
                → [decision-trees.md]     → Verify original architectural decisions
                → Fix + add regression test
```

### Collaboration & Governance Pipeline

```
Team Decision → [collaboration-patterns.md] → Git branching strategy, commit conventions
              → [collaboration-patterns.md] → Code review workflow + review pyramid
              → [patterns-architecture.md] → ADR lifecycle management
              → [collaboration-patterns.md] → Postmortem template for incidents
```

---

## Meta-Prompting Guidelines

Activate these meta-tags based on task complexity. Full definitions and examples: `references/meta-prompting.md`.

| Meta-Tag | Purpose | When to Activate |
|----------|---------|------------------|
| `<persistence>` | Autonomous completion — never stop on uncertainty | Multi-step tasks, complex implementations |
| `<exploration>` | Thorough investigation — never guess | Unfamiliar codebase, ambiguous requirements |
| `<self_reflection>` | Internal 7-dimension quality rubric scoring | Core services, security-sensitive, high-traffic paths |
| `<reasoning_effort>` | Cognitive depth: low / medium / high | Scale to task complexity (high for reviews/refactoring) |
| `<code_editing_rules>` | Structured frontend implementation guidelines | Frontend projects, UI/UX-sensitive work |

---

## Pre-Generation Checklist

Apply **before** output. Core gate: C1 (boundary validation), C2 (no silent failures), C6 (security), C8 (≤ 60 lines), C9 (atomicity).
Full checklist with P0/P1/P2 tiers: `references/pre-generation-checklist.md`.

**MUST ALSO pass all Architecture Gates (G0-G7)**: `references/architectural-gates.md`.

---

## Generation Constraints (MANDATORY)

These constraints are the difference between "working code" and "production-ready code".
Detailed definitions, violation examples, and enforcement strategies: `references/generation-constraints.md`.

| # | Constraint |
|---|-----------|
| C1 | **Input Validation at Boundary** — validate at system entry, never propagate bad data |
| C2 | **No Silent Failures** — every error path either recovers or fails observably |
| C3 | **Always Include Tests** — happy path + error path + edge case |
| C4 | **Explain Non-Obvious Decisions** — comment "why", not "what" |
| C5 | **No Simplified "Demo" Code** — production patterns only |
| C6 | **Security by Default** — parameterized queries, no secrets in logs, least privilege |
| C7 | **Resource Cleanup** — deterministic close/finalize, try-with-resources |
| C8 | **Method Length ≤ 60 lines** — single level of abstraction per method |
| C9 | **Atomicity Guarantee** — all-or-nothing mutations, no partial state |
| C10 | **Idempotency** — POST/PATCH/Payment protected by idempotency key |
| C11 | **Observability Built-in** — metrics, structured logs, traces on critical paths |
| C12 | **Configuration Externalization** — no hardcoded values, env-driven |
| C13 | **Backward Compatibility** — API changes preserve N-1 compatibility |
| C14 | **Documentation Sync** — ADR for architectural decisions, OpenAPI annotations |
| C15 | **Dependency Minimalism** — prefer stdlib, justify every new dependency |

---

## Architecture Constraints (MANDATORY — stronger than C1-C15)

These are hard architectural rules. Violating them means the code is NOT architect-level, regardless of C1-C15 compliance.
Detailed definitions and enforcement: `references/architectural-gates.md`.

| Gate | Constraint |
|------|-----------|
| G1 | **Service MUST return domain objects, NOT DTOs** — DTO mapping is Controller/Mapper responsibility |
| G1 | **Controller MUST return DTOs, NOT entities** — no entity leak to HTTP layer |
| G1 | **Service MUST NOT import HTTP types** — no HttpServletRequest, no @RequestBody in Service |
| G1 | **Controller MUST NOT access Repository directly** — always go through Service |
| G1 | **Dedicated Mapper class for domain ↔ DTO conversion** — no buildResponse() in Service |
| G2 | **No check-then-act without atomicity** — TOCTOU race conditions prohibited |
| G3 | **POST/PATCH endpoints MUST require Idempotency-Key** — no auto-UUID fallback |
| G4 | **Spring Security MUST configure entry points** — no HTML error pages on API |
| G4 | **Global exception handler MUST have catch-all** — no unhandled exceptions reach client |
| G5 | **Aggregate root enforces its own invariants** — no business logic in Service |
| G6 | **List/detail endpoints MUST use DTO projections** — no entity loading + Service mapping |
| G7 | **Zero hardcoded environment-dependent values** — all via ${ENV_VAR:default} |

---

## Core Philosophy

The difference between correct code and expert code is knowing:

1. **When to follow a principle and when to break it** — context sensitivity
2. **Which pattern to apply given ambiguous signals** — decision trees
3. **What failure looks like before it happens** — anti-pattern recognition
4. **How to leave room for unknown future change** — evolvability
5. **Architecture is non-negotiable** — clean layers, atomic operations, security boundaries

---

## When to Consult Which File

| Situation | Primary Reference | Secondary |
|-----------|-------------------|-----------|
| Starting any code generation | **`architectural-gates.md`** | `context-branching.md` |
| Domain modeling (DDD) | `ddd.md` | `decision-trees.md` |
| Writing new code | `decision-trees.md` → `patterns.md` | `design-principles.md` |
| API design | `api-design.md` | `patterns-crud.md` |
| Database design | `database-design.md` | `patterns-architecture.md` |
| Event-driven architecture | `event-driven-architecture.md` | `ddd.md` |
| Resilience (circuit breaker, timeout, retry) | `resilience-patterns.md` | `design-principles.md` |
| Performance optimization | `performance-optimization.md` | `cloud-native.md` |
| Capacity planning & scaling | `capacity-planning.md` | `cloud-native.md` |
| Cost optimization (FinOps) | `cost-optimization.md` | `capacity-planning.md` |
| Safe refactoring (zero-downtime) | `refactoring-patterns.md` | `patterns-architecture.md` |
| Team collaboration & Git strategy | `collaboration-patterns.md` | `review-template.md` |
| CI/CD pipeline design | `cicd-patterns.md` | `cloud-native.md` |
| Observability & SLOs | `observability-patterns.md` | `performance-optimization.md` |
| API lifecycle & versioning | `api-lifecycle.md` | `api-design.md` |
| Auth & identity (OAuth2/OIDC) | `auth-patterns.md` | `security-patterns.md` |
| Reviewing code | `architectural-gates.md` → `review-template.md` → `anti-patterns.md` | `decision-trees.md` |
| Choosing architecture | `context-branching.md` → `patterns-architecture.md` | `ddd.md` |
| Resolving design conflicts | `design-principles.md` → `decision-trees.md` | `anti-patterns.md` |
| Refactoring | `anti-patterns.md` → `patterns.md` | `context-branching.md` |
| Debugging | `anti-patterns.md` → `security-patterns.md` | `resilience-patterns.md` |
| Writing tests | `testing-patterns.md` | `context-branching.md` |
| Security review | `security-patterns.md` | `anti-patterns.md` |
| Prompt engineering | `meta-prompting.md` | `context-branching.md` |
| Before/After examples | `examples.md` | `patterns.md` |
| Language/framework specifics | `java.md` / `kotlin.md` / `golang.md` / `python.md` / `springboot.md` | — |
| Cloud-native deployment | `cloud-native.md` | `patterns-architecture.md` |
| Frontend development | `frontend-excellence.md` | `patterns.md` |
| Data engineering | `data-engineering.md` | `patterns-architecture.md` |
| AI/ML engineering | `ai-ml-engineering.md` | `cloud-native.md` |
| Compliance & governance | `compliance-governance.md` | `security-patterns.md` |

---

## Reference File Index

| File | Purpose |
|------|---------|
| `architectural-gates.md` | **NEW** — Mandatory architecture gates (G0-G7), layer enforcement, TOCTOU prevention |
| `design-principles.md` | 10 universal design principles with code examples |
| `context-branching.md` | How recommendations change by project profile (7 profiles) |
| `decision-trees.md` | 20 signal-driven decision trees for design choices |
| `ddd.md` | Domain-Driven Design: aggregates, value objects, domain events, repositories |
| `api-design.md` | REST/gRPC/GraphQL design, versioning, pagination, error responses |
| `database-design.md` | Index strategy, read/write splitting, connection pooling, query optimization, Flyway |
| `patterns.md` | 16 reusable patterns with multi-language implementations |
| `patterns-crud.md` | Production-grade CRUD controller/service/repository stacks |
| `patterns-architecture.md` | Architect-level patterns (ADR, C4, Bounded Context, Multi-Tenancy, Event Schema) |
| `anti-patterns.md` | 27 wrong-code examples with root cause + expert fix |
| `resilience-patterns.md` | Circuit Breaker, Bulkhead, Retry+Backoff+Jitter, Rate Limiting, Load Shedding, Timeout Propagation |
| `event-driven-architecture.md` | Event Sourcing, CQRS, Message Ordering, Dead Letter Queue, Exactly-Once vs At-Least-Once |
| `performance-optimization.md` | Caching tiers (L1/L2/L3), batch vs stream, async patterns, serialization trade-offs |
| `security-patterns.md` | OWASP mapping, JWT lifecycle, RBAC/ABAC, audit logging, SAST/DAST |
| `testing-patterns.md` | Given-When-Then, table-driven, property-based, contract testing, chaos engineering |
| `review-template.md` | Structured 6-section code review template |
| `meta-prompting.md` | Meta-tags (`<persistence>`, `<exploration>`, `<self_reflection>`, etc.) + PCTF Framework |
| `examples.md` | 5 Before/After transformation examples demonstrating SKILL principles in action |
| `generation-constraints.md` | C1-C15 detailed definitions, violation examples, enforcement strategies |
| `pre-generation-checklist.md` | P0/P1/P2 quality gates with scoring rules and thresholds |
| `cloud-native.md` | Kubernetes, containerization, health probes, ConfigMap/Secret management |
| `frontend-excellence.md` | TypeScript/React/Vue code quality, component design, state management |
| `data-engineering.md` | CDC (Debezium), data pipelines, ETL/ELT, data consistency, schema evolution |
| `ai-ml-engineering.md` | Model serving, feature stores, A/B testing, MLOps, LLM engineering |
| `compliance-governance.md` | GDPR, code governance, API governance, audit logging, compliance automation |
| `refactoring-patterns.md` | Strangler Fig, Branch by Abstraction, Feature Toggle, Parallel Change, Dark Launching |
| `collaboration-patterns.md` | Git branching strategy, Conventional Commits, Code Review workflow, ADR lifecycle, Postmortems |
| `capacity-planning.md` | Load estimation (Little's Law), horizontal/vertical scaling, HPA tuning, DB sharding, rate limiting |
| `cost-optimization.md` | Resource right-sizing, spot instances, data transfer costs, storage tiering, observability sampling |
| `cicd-patterns.md` | Deployment strategy, pipeline templates, artifact management (SBOM), feature-flag release, DB migrations in CI |
| `observability-patterns.md` | SLI/SLO/SLA design, dashboard architecture, alerting strategy, distributed tracing, structured logging |
| `api-lifecycle.md` | API versioning, deprecation lifecycle (Sunset header), gateway patterns, contract testing (Pact), OpenAPI docs-as-code |
| `auth-patterns.md` | OAuth2/OIDC architecture, token lifecycle & rotation, RBAC/ABAC, SSO/SAML federation, zero-trust architecture |
| `java.md` / `kotlin.md` / `golang.md` / `python.md` | Language-specific expert practices |
| `springboot.md` | Spring Boot 3.2+ expert practices (DI, transactions, cache, resilience) |

---

## Limitations

- This skill encodes **transferable expertise patterns**, not exhaustive domain knowledge.
- Domain-specific patterns (e.g., fintech settlement, healthcare FHIR) belong in separate skills.
- The goal is **pragmatic mastery**, not academic perfection.
- All rules have exceptions. The skill teaches you how to *recognize* valid exceptions.

### Cross-Platform Compatibility

| Platform | Adaptation Path |
|---|---|
| **Cursor** | Convert reference files to `.cursor/rules/*.mdc` files |
| **Claude Code** | Merge SKILL.md into `CLAUDE.md`; reference files under `.claude/skills/` |
| **GitHub Copilot** | Extract core constraints (C1-C15) + architecture gates into `.github/copilot-instructions.md` |

---

## How to Validate This Skill

### Method 1: Regression Test
Run the same prompt **with and without** the SKILL. Compare on: input validation (C1), error handling (C2), method length (C8), observability (C11), **layer architecture (G1)**.

### Method 2: Anti-Pattern Trap
| Prompt | Expected Behavior |
|--------|-------------------|
| "Write a function to parse user input and save to DB" | Include parameterized queries (AP-1 prevention) |
| "Handle the error silently" | Resist silent failure (AP-3), propose structured error handling |
| "Just make it work, skip validation" | Push back and include boundary validation (C1) |

### Method 3: Architecture Gate Audit
Request a CRUD feature and check against G1-G7:
- Service returns DTOs? → **G1 fail**
- Check-then-act without atomicity? → **G2 fail**
- No Idempotency-Key required? → **G3 fail**
- No Spring Security entry points? → **G4 fail**
- Business logic in Service instead of domain? → **G5 fail**
- No DTO projections for list endpoint? → **G6 fail**
- Hardcoded URLs or credentials? → **G7 fail**

If fewer than 5 of 7 gates pass, the SKILL is not enforcing architecture properly.
