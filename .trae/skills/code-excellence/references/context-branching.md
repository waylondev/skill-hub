# Context Branching

## Purpose

The same principle applied to different contexts yields different code. This reference
encodes how expert recommendations CHANGE based on the project context.

Always determine the context profile FIRST, then apply the appropriate variant.

---

## Context Profiles

### Profile 1: Startup MVP
- **Priority**: Speed > correctness edge cases > maintainability
- **Team**: 1-5 developers, rapid iteration
- **Lifespan**: Unknown, may be rewritten

### Profile 2: Scale-Up Product
- **Priority**: Developer velocity + safety balance
- **Team**: 5-30 developers, multiple teams
- **Lifespan**: Years, active development

### Profile 3: Enterprise Core System
- **Priority**: Correctness > safety > everything
- **Team**: 30+ developers, strict governance
- **Lifespan**: Decades, stable core with feature additions

### Profile 4: Critical Infrastructure
- **Priority**: Reliability + observability > velocity
- **Team**: Small expert team
- **Lifespan**: Long, infrequent changes

---

## Branching Table: Principle Application by Context

### Testing Depth

| Context | Unit Test Coverage | Integration Test Strategy | E2E Tests |
|---------|-------------------|--------------------------|-----------|
| Startup MVP | Critical paths only (~40%) | Manual or none | Smoke test only |
| Scale-Up | Core domain 80%+ | Key integrations: Testcontainers | Critical user journeys |
| Enterprise | 90%+ branch coverage | Every external integration | Full regression suite |
| Critical Infra | 95%+ with mutation testing | Chaos engineering + fault injection | Continuous synthetic monitoring |

### Error Handling Strategy

| Context | Approach | Example |
|---------|----------|---------|
| Startup MVP | Fail fast, log details, 500 is acceptable | `throw new RuntimeException("Charge failed: " + resp)` |
| Scale-Up | Typed errors, consistent API contract | `sealed interface PaymentResult { ... }` |
| Enterprise | Full error taxonomy, i18n messages, audit trail | Structured error codes mapped to RFC 7807 Problem Details |
| Critical Infra | Every error case enumerated, runbooks attached | Error codes → alert routing → on-call playbook |

### Dependency Injection

| Context | Approach |
|---------|----------|
| Startup MVP | Constructor injection with manual wiring. No DI framework if project is tiny. |
| Scale-Up | Spring / Dagger / manual DI with clear conventions. Constructor injection only. |
| Enterprise | Spring Boot with strict conventions, ArchUnit rules enforcing DI patterns. |
| Critical Infra | Explicit manual wiring, no magic. Every dependency visible in `main`. |

### Database Schema Evolution

| Context | Approach |
|---------|----------|
| Startup MVP | Migrations from day one (Flyway/Liquibase). `ddl-auto: update` okay in dev only. |
| Scale-Up | Strict migration discipline. Expand-contract for zero-downtime. |
| Enterprise | Full expand-contract. Every migration reviewed. Rollback plan required. |
| Critical Infra | Multi-phase rollout. Backward-compatible for N-1 versions. No destructive changes. |

### Logging & Observability

| Context | Approach |
|---------|----------|
| Startup MVP | Structured logging (JSON). Console output. Alert on ERROR. |
| Scale-Up | Centralized logging (ELK/Loki). Metrics (Prometheus). Tracing (OpenTelemetry). |
| Enterprise | Full observability stack. SLO/SLI defined per service. Anomaly detection. Audit trail. |
| Critical Infra | Every decision logged with trace context. Metrics dashboard per component. Synthetic probes. |

### Feature Flags

| Context | Approach |
|---------|----------|
| Startup MVP | Simple boolean flags. Environment variable toggles are sufficient. |
| Scale-Up | Toggle service with per-tenant/percentage rollout. Kill switches for risky paths. |
| Enterprise | Full feature flag platform (LaunchDarkly/Split). A/B testing. Gradual rollout. |
| Critical Infra | Circuit breakers + manual toggles. Every toggle has an owner + expiry. |

### Error Budget & SLO

| Context | SLO Target | Handling |
|---------|-----------|----------|
| Startup MVP | Informal: "don't be down too often" | Best effort |
| Scale-Up | 99.9% availability (43 min/month downtime) | Alert on budget burn > 50% |
| Enterprise | 99.95%-99.99% depending on service tier | Strict error budget. Freeze features when budget exhausted. |
| Critical Infra | 99.99%-99.999% | Automated rollback on SLO breach. Every incident has RCA. |

---

## Context-Driven Architecture Decisions

### Monolith Boundaries

| Context | Recommendation |
|---------|---------------|
| Startup MVP | Single module. Package-by-feature is sufficient. Don't over-structure. |
| Scale-Up | Modular monolith. Use ArchUnit / Spring Modulith to enforce module boundaries. Separate API modules for inter-module contracts. |
| Enterprise | Bounded contexts as separate deployables or strict modular monolith with governance. |
| Critical Infra | Single deployable with compile-time module enforcement. No runtime module loading. |

### Database per Service

| Context | Recommendation |
|---------|---------------|
| Startup MVP | Single database. Shared schema. Simplicity wins. |
| Scale-Up | Single database, separate schemas per bounded context. Logical separation without operational cost. |
| Enterprise | Separate databases per service where strong isolation required. Careful with cross-service queries. |
| Critical Infra | Dedicated database per component. No sharing. Every component independently scalable. |

### Caching Strategy

| Context | Recommendation |
|---------|---------------|
| Startup MVP | Don't cache prematurely. Add when profiling shows a bottleneck. |
| Scale-Up | Cache-Aside for hot data. Redis for shared cache across instances. |
| Enterprise | Multi-tier caching (Caffeine local + Redis distributed). Cache warming strategies. |
| Critical Infra | Deterministic caching with bounded memory. Cache hit rate SLIs. No cache-induced inconsistency tolerated. |

### Deployment Frequency

| Context | Cadence | Strategy |
|---------|---------|----------|
| Startup MVP | Multiple times daily | Trunk-based. Feature flags optional. |
| Scale-Up | Daily to weekly | Trunk-based with feature flags. CI/CD pipeline. |
| Enterprise | Weekly to monthly | Staged rollout. Change advisory board. Full regression. |
| Critical Infra | Monthly to quarterly | Canary → blue/green → full rollout. Extensive pre-prod validation. |

---

## Context-Aware Pattern Selection

### Handling External API Failures

| Context | Pattern |
|---------|---------|
| Startup MVP | Try-catch with retry (1-2 retries). Log error. |
| Scale-Up | Circuit Breaker + Retry with exponential backoff + jitter. |
| Enterprise | Circuit Breaker + Bulkhead + Fallback response. Metrics for SLI tracking. |
| Critical Infra | Full resilience stack + degraded mode operation + automated recovery playbooks. |

### User Input Validation

| Context | Pattern |
|---------|---------|
| Startup MVP | Basic null/empty checks. Bean Validation on DTOs. |
| Scale-Up | Bean Validation + business rule validation in service layer. Clear error contract. |
| Enterprise | Multi-layer validation: syntactic (Bean Validation) → semantic (business rules) → contextual (user permissions, rate limits). |
| Critical Infra | Whitelist validation. Reject unknown fields. Idempotency on all mutations. Audit every rejection. |

---

## How to Use Context Branching

1. **Classify the project** into one of the four profiles (Startup MVP / Scale-Up / Enterprise / Critical Infra)
2. **For each design decision**, consult the relevant branching table above
3. **Apply the context-appropriate variant**, not the generic advice
4. **When the context changes** (e.g., MVP graduates to Scale-Up), revisit decisions

**Do NOT apply enterprise patterns to a startup MVP.** The right code for Stripe's payment
engine is wrong for your weekend project. Context is not an excuse — it's the primary
determinant of what "good code" means.
