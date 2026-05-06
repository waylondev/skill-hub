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

### Security Configuration — MVP Degradation

| Context | Authentication | Authorization | Security Headers | HTTPS |
|---------|---------------|---------------|-----------------|-------|
| Startup MVP | Basic auth or simple JWT. Can skip OAuth2 complexity. | Role check at controller level with `@PreAuthorize`. | Minimal CSP, no HSTS. Can skip strict-transport-security. | TLS required but can use Let's Encrypt auto-renewal. |
| Scale-Up | OAuth2/OIDC with authorization server (Keycloak/Auth0). JWT access + refresh tokens. | RBAC at service layer with AOP interceptors. Fail-closed by default. | Full security headers: CSP, HSTS, X-Frame-Options, X-Content-Type-Options. | TLS 1.2+ enforced. Certificate pinning for mobile clients. |
| Enterprise | OAuth2/OIDC + MFA. SSO integration with corporate IdP. Session management with revocation. | ABAC with policy engine. Resource-level permissions. Context-aware rules. | Strict CSP with nonce-based script loading. Report-Only mode first, then enforce. | Mutual TLS for service-to-service. HSTS preloaded. |
| Critical Infra | Hardware-backed authentication (FIDO2/YubiKey). Biometric + password + OTP. Zero-trust architecture. | Continuous authorization — re-evaluated per request with context. Real-time policy updates. | Maximum security posture. CSP + Reporting + Monitoring. Violation alerts to security team. | End-to-end encryption. Client certificates required. Network segmentation. |

### MVP Security Degradation Patterns

When building an MVP, full enterprise security adds friction. Use these **safe degradation patterns** that maintain baseline security without the operational overhead:

```java
// ❌ Wrong for MVP: Skipping auth entirely
// No auth → anyone can access everything → data breach

// ✅ Safe MVP: Simple JWT without OAuth2 complexity
public class SimpleJwtFilter extends OncePerRequestFilter {
    private final String jwtSecret = System.getenv("JWT_SECRET");  // at minimum, externalized

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) {
        var token = extractToken(request);
        if (token != null && validateToken(token)) {
            SecurityContextHolder.getContext()
                .setAuthentication(new JwtAuthentication(parseClaims(token)));
        }
        chain.doFilter(request, response);
    }
}

// ❌ Wrong for MVP: No input validation
// @PostMapping("/orders") public Order create(@RequestBody Object req) { ... }

// ✅ Safe MVP: Basic Bean Validation at minimum
@PostMapping("/orders")
public Order create(@Valid @RequestBody CreateOrderRequest req) {
    // At minimum: validate structure, not business rules
    return orderService.create(req);
}

// ❌ Wrong for MVP: No error handling at all
// try { ... } catch (Exception e) { log.error("error", e); }

// ✅ Safe MVP: Fail fast with structured error
@ExceptionHandler(Exception.class)
public ResponseEntity<ApiError> handleGlobal(Exception e) {
    return ResponseEntity.status(500)
        .body(new ApiError("INTERNAL_ERROR", "An unexpected error occurred"));
    // No stack trace to client, but log it server-side
}
```

**MVP Security Checklist** (minimum acceptable):
- [ ] Authentication exists — even if simple JWT, no unprotected endpoints
- [ ] Input validation at API boundary — `@Valid` on all request bodies
- [ ] No secrets in source code — environment variables at minimum
- [ ] HTTPS in production — no HTTP-only endpoints serving user data
- [ ] Error responses don't leak internals — generic 500, detailed server logs
- [ ] Rate limiting on authentication endpoints — prevent brute force

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

---

## New Context Profiles

### Profile 5: AI/ML Project
- **Priority**: Reproducibility > experiment velocity > scalability
- **Team**: Data scientists + ML engineers + platform engineers
- **Lifespan**: Models retrained frequently; pipelines evolve continuously

#### Characteristics
- Experiment-driven development: most features start as notebooks
- Heavy data dependencies: training data, feature stores, model artifacts
- GPU resource constraints: training is expensive; inference must be cost-efficient
- Model versioning: every deployed model must be traceable to training run
- Reproducibility: same code + same data + same hyperparameters = same model
- Regulatory sensitivity: model fairness, explainability, data privacy

#### Architectural Implications
- Separate training and serving pipelines; never train in production
- Feature store (online + offline) ensures training/serving consistency
- Model registry tracks lineage: code version → data version → hyperparameters → metrics → artifact
- A/B testing infrastructure for model comparison
- Data versioning (DVC, LakeFS) alongside code versioning

#### Code Style Shifts
- Python-first for model code; Java/Go for serving infrastructure
- Configuration-driven: hyperparameters, model architectures, data splits in YAML/JSON
- Notebook code must be refactored into tested modules before production
- Defensive data handling: schema validation, drift detection, outlier handling

#### Quality Gate Differences
| Gate | AI/ML Standard |
|------|---------------|
| Test Coverage | 80%+ for serving code; 60%+ for training pipelines |
| Model Testing | Unit tests for feature engineering; integration tests for inference; shadow testing for new models |
| Data Quality | Great Expectations / dbt tests on input data; anomaly detection on features |
| Performance | Inference latency p99 < 100ms; throughput benchmarks per model version |
| Fairness | Bias metrics (demographic parity, equalized odds) within thresholds |

#### Anti-Patterns to Watch For
- **Training-serving skew**: different feature computation in training vs inference
- **Data leakage**: test data contaminating training through temporal or ID leakage
- **Undocumented experiments**: notebooks without version control or parameter logging
- **Model bloat**: deploying oversized models without quantization or distillation
- **No monitoring**: deployed model with no drift detection or performance tracking

---

### Profile 6: Frontend Project
- **Priority**: User experience > developer experience > bundle size
- **Team**: Frontend engineers, UX designers, product managers
- **Lifespan**: Months to years; frequent UI iterations

#### Characteristics
- User-facing: every pixel affects conversion and satisfaction
- Build-time complexity: bundling, transpilation, tree-shaking, code splitting
- Runtime environment: diverse browsers, devices, network conditions
- State complexity: local UI state, server state, global app state, URL state
- Accessibility: legal requirement in many jurisdictions

#### Architectural Implications
- Component architecture: atomic design, compound components, or headless UI
- State management decision tree: Local → Context → Zustand → Redux → React Query
- Rendering strategy: CSR vs SSR vs SSG vs ISR — choose based on content freshness and SEO needs
- Asset optimization: images (WebP/AVIF), fonts (subset), icons (SVG sprite)
- Build pipeline: Vite/Webpack/Rspack with bundle analysis budgets

#### Code Style Shifts
- TypeScript strict mode: `strictNullChecks`, `noImplicitAny`, `noUncheckedIndexedAccess`
- Component design: single responsibility, explicit props, composition over inheritance
- Hooks discipline: custom hooks for reusable logic; no logic in JSX
- CSS architecture: design tokens, utility-first (Tailwind) or CSS Modules

#### Quality Gate Differences
| Gate | Frontend Standard |
|------|------------------|
| Test Coverage | 70%+ unit (React Testing Library); 80%+ critical user flows (E2E) |
| Accessibility | WCAG 2.1 AA compliance; axe-core automated checks; keyboard navigation tested |
| Performance | Lighthouse score ≥ 90; Core Web Vitals (LCP < 2.5s, FID < 100ms, CLS < 0.1) |
| Bundle Size | Budget enforced in CI; main chunk < 200KB gzipped |
| Browser Support | Last 2 versions + evergreen; polyfills only for critical features |

#### Anti-Patterns to Watch For
- **Prop drilling**: passing props through 3+ component layers instead of context or state management
- **Excessive re-renders**: missing `memo`, `useMemo`, `useCallback` on expensive components
- **Any types**: `any` in TypeScript defeats the purpose; use `unknown` with type guards
- **Inline styles**: mixing CSS-in-JS with inline styles creates specificity chaos
- **Ignoring cleanup**: `useEffect` without cleanup causes memory leaks and stale subscriptions

---

### Profile 7: Mobile Project
- **Priority**: Offline functionality > battery efficiency > startup time
- **Team**: Mobile engineers, backend-for-frontend developers, QA
- **Lifespan**: Years; app store release cycles slow iteration

#### Characteristics
- Device constraints: limited memory, battery, storage, CPU
- Network variability: offline-first is not optional
- Platform gatekeepers: App Store / Play Store review processes
- Native capabilities: camera, GPS, push notifications, biometric auth
- Update friction: users may skip updates; backward compatibility matters

#### Architectural Implications
- Offline-first: local database (SQLite/Room/Core Data) syncs with backend
- State sync: conflict resolution (last-write-wins vs CRDT vs custom merge)
- Push notification strategy: FCM/APNs with fallback polling
- Battery optimization: batch network requests, reduce GPS polling, defer background work
- Code sharing: React Native/Flutter for cross-platform; native modules for platform-specific features

#### Code Style Shifts
- Platform idioms: follow iOS Human Interface Guidelines / Material Design
- Navigation: declarative (React Navigation, Flutter Navigator 2.0) with deep linking
- State management: Redux/MobX/Zustand (React Native); BLoC/Riverpod (Flutter)
- Error handling: user-friendly messages; retry with exponential backoff; offline indicators

#### Quality Gate Differences
| Gate | Mobile Standard |
|------|----------------|
| Test Coverage | 70%+ unit; 60%+ integration; critical flows covered by E2E (Maestro/Detox) |
| Performance | Cold start < 2s; memory usage < 150MB; battery drain < 5% per hour of active use |
| Offline | Core flows work offline; sync queue handles conflicts gracefully |
| Accessibility | Screen reader support; dynamic type; high contrast mode |
| Store Compliance | No private API usage; privacy manifest (iOS); data safety declaration (Android) |

#### Anti-Patterns to Watch For
- **Synchronous network on main thread**: blocks UI; always use async patterns
- **Storing sensitive data insecurely**: use Keychain/Keystore; never plain UserDefaults/SharedPreferences
- **Ignoring app lifecycle**: background/foreground transitions must pause/resume resources
- **Hardcoded API URLs**: use build configuration for environment switching
- **No crash reporting**: unhandled exceptions must be captured (Firebase Crashlytics, Sentry)

---

## Updated Branching Tables (Including New Contexts)

### Testing Depth (Extended)

| Context | Unit Test Coverage | Integration Test Strategy | E2E Tests |
|---------|-------------------|--------------------------|-----------|
| Startup MVP | Critical paths only (~40%) | Manual or none | Smoke test only |
| Scale-Up | Core domain 80%+ | Key integrations: Testcontainers | Critical user journeys |
| Enterprise | 90%+ branch coverage | Every external integration | Full regression suite |
| Critical Infra | 95%+ with mutation testing | Chaos engineering + fault injection | Continuous synthetic monitoring |
| AI/ML | 80%+ serving; 60%+ training | Model inference integration; data pipeline validation | Shadow testing; A/B test validation |
| Frontend | 70%+ unit (RTL) | API mocking (MSW); component testing | Critical user flows (Playwright/Cypress) |
| Mobile | 70%+ unit | API mocking; sync logic testing | Critical flows (Maestro/Detox) |

### Deployment Frequency (Extended)

| Context | Cadence | Strategy |
|---------|---------|----------|
| Startup MVP | Multiple times daily | Trunk-based. Feature flags optional. |
| Scale-Up | Daily to weekly | Trunk-based with feature flags. CI/CD pipeline. |
| Enterprise | Weekly to monthly | Staged rollout. Change advisory board. Full regression. |
| Critical Infra | Monthly to quarterly | Canary → blue/green → full rollout. Extensive pre-prod validation. |
| AI/ML | Weekly model updates; daily pipeline fixes | Canary model rollout. Automated rollback on metric degradation. |
| Frontend | Daily to weekly | Vercel/Netlify preview deployments. Visual regression checks. |
| Mobile | Bi-weekly to monthly | TestFlight/Internal Testing → staged rollout → full release. |

---

## How to Use Context Branching

1. **Classify the project** into one of the seven profiles (Startup MVP / Scale-Up / Enterprise / Critical Infra / AI/ML / Frontend / Mobile)
2. **For each design decision**, consult the relevant branching table above
3. **Apply the context-appropriate variant**, not the generic advice
4. **When the context changes** (e.g., MVP graduates to Scale-Up), revisit decisions

**Do NOT apply enterprise patterns to a startup MVP.** The right code for Stripe's payment
engine is wrong for your weekend project. Context is not an excuse — it's the primary
determinant of what "good code" means.

## Quick Checklist

- [ ] Project context identified (MVP / Scale-Up / Enterprise / Critical Infra / AI/ML / Frontend / Mobile)
- [ ] Testing depth aligned with context
- [ ] Error handling strategy appropriate for criticality
- [ ] Deployment frequency matches team size and risk tolerance
- [ ] Architecture decisions (monolith, database, caching) fit current scale
- [ ] Context-specific anti-patterns reviewed
- [ ] Plan for context evolution documented (when to upgrade patterns)

---

## Language-Specific Constraint Adaptation

Generation constraints (C1-C15) may need language-specific interpretation. This section defines how each constraint adapts per language.

### Method Length (C8) by Language

| Language | Limit | Rationale |
|----------|-------|-----------|
| **Java** | ≤ 60 lines | Standard convention, fits on screen |
| **Kotlin** | ≤ 40 lines | Concise syntax; 40 Kotlin lines ≈ 60 Java lines in expressiveness |
| **Go** | ≤ 50 lines | Go favors flat, explicit code over nested abstractions |
| **Python** | ≤ 40 lines | Python's indentation consumes horizontal space; vertical clarity matters |
| **TypeScript** | ≤ 50 lines | Mix of types + logic; types don't count toward limit if separated |

### Error Handling (C2) by Language

| Language | Strategy | Detail |
|----------|----------|--------|
| **Java** | Typed exceptions + Result type for expected failures | `throws` for checked, RuntimeException for unexpected, sealed interface for business outcomes |
| **Kotlin** | Result type preferred, exceptions for truly exceptional | `Result<T>` for validation, `throw` for programmer error |
| **Go** | Explicit error returns, never ignore | `if err != nil` must handle; use sentinel errors for comparison |
| **Python** | Exception hierarchy + custom exceptions | Define domain-specific exceptions; use `logging.exception()` with context |
| **TypeScript** | Result type + try/catch boundary | `Result<T, E>` pattern; throw only at boundaries, return Result internally |

### Input Validation (C1) by Language

| Language | Approach | Detail |
|----------|----------|--------|
| **Java** | Bean Validation (JSR-380) + constructor validation | `@Valid`, `@NotNull`, custom validators; fail fast in constructor |
| **Kotlin** | Constructor init blocks + value classes | `init { require(...) }`; inline classes for typed primitives |
| **Go** | Validation functions, never trust input | Struct tags + validator library; validate before business logic |
| **Python** | Pydantic models + type hints | `pydantic.BaseModel` with validators; reject at entry point |
| **TypeScript** | Zod/io-ts schema validation | Runtime validation at API boundary; `zod.parse()` before processing |

### Resource Cleanup (C7) by Language

| Language | Pattern | Detail |
|----------|---------|--------|
| **Java** | try-with-resources | `AutoCloseable` for DB connections, streams, HTTP clients |
| **Kotlin** | `use {}` extension | `use {}` for any `Closeable`; `coroutineScope` for structured concurrency |
| **Go** | `defer` | `defer file.Close()`, `defer resp.Body.Close()` — right after resource acquisition |
| **Python** | `with` statement / context managers | `with open(...)`, `@contextmanager`, `__enter__`/`__exit__` |
| **TypeScript** | `try/finally` + async disposal | `finally { await client.disconnect() }`; `using` (ES2024 Disposable) |

### Atomicity (C9) by Language

| Language | Approach | Detail |
|----------|----------|--------|
| **Java** | `@Transactional` + compensating actions | Spring TX for DB, Saga for distributed |
| **Kotlin** | `transaction {}` (Exposed) + `@Transactional` (Spring) | Same as Java, plus coroutine transaction integration |
| **Go** | Manual transaction with defer rollback | `tx, _ := db.Begin(); defer tx.Rollback()` — rollback if commit not reached |
| **Python** | Context manager for transaction | `with db.transaction():` or `@transaction.atomic` |
| **TypeScript** | Explicit transaction scope | Prisma `$transaction`, TypeORM `manager.transaction` |

### Idempotency (C10) by Language

| Language | Typical Implementation | Detail |
|----------|----------------------|--------|
| **Java** | Idempotency store + `@Transactional` | Redis or DB-based deduplication with key TTL |
| **Kotlin** | Same as Java + `suspend` function support | Coroutine-scoped idempotency check |
| **Go** | Redis SET NX + DB unique constraint | Two-layer protection: cache first, DB constraint as safety net |
| **Python** | Database unique index on idempotency key | `INSERT ... ON CONFLICT DO NOTHING` + check affected rows |
| **TypeScript** | Redis-based with Prisma/Drizzle | `SET idempotency_key EX 86400 NX` — atomic check-and-set |

### Observability (C11) by Language

| Language | Instrumentation | Detail |
|----------|----------------|--------|
| **Java** | Micrometer + OpenTelemetry | Auto-instrumentation for Spring; manual `@Timed` for business metrics |
| **Kotlin** | Same as Java + coroutine context propagation | OpenTelemetry with `CoroutineContext` for trace propagation |
| **Go** | `otel-go` + `prometheus/client_golang` | Context-based trace propagation; middleware for HTTP/gRPC |
| **Python** | OpenTelemetry SDK + structlog | `@trace` decorators; structured JSON logging with `extra` context |
| **TypeScript** | OpenTelemetry JS + Pino logger | AsyncLocalStorage for trace context; middleware injection |

### Configuration Externalization (C12) by Language

| Language | Approach | Detail |
|----------|----------|--------|
| **Java** | `@ConfigurationProperties` + environment variables | Spring Boot `application.yml` with `${ENV_VAR}` overrides |
| **Kotlin** | Same as Java + Ktor configuration | `hocon` or `yaml` config with env variable substitution |
| **Go** | Viper + env variables | `viper.BindEnv()`, `os.LookupEnv()` with defaults |
| **Python** | `pydantic-settings` + `.env` files | `BaseSettings` with `env_file` and validation |
| **TypeScript** | `dotenv` + runtime schema validation | `zod` schema for env variables; fail fast if required vars missing |

### Dependency Minimalism (C15) by Language

| Language | Guidance | Detail |
|----------|----------|--------|
| **Java** | Prefer Spring ecosystem; avoid duplicate functionality | Don't add Jackson if you already have Spring Boot (includes Jackson) |
| **Kotlin** | Leverage stdlib (kotlinx.coroutines, kotlinx.serialization) | Many Java libraries are replaced by Kotlin-native alternatives |
| **Go** | Stdlib is comprehensive; only add what's truly missing | `net/http`, `encoding/json`, `database/sql` cover most needs |
| **Python** | Prefer stdlib; be cautious with heavy dependencies | `requests` > `urllib`, but avoid heavy frameworks for simple tasks |
| **TypeScript** | Node.js ecosystem is vast; evaluate bundle impact | Every dependency adds to bundle size; prefer tree-shakeable imports |

---

## How to Apply Language-Specific Adaptation

1. **Identify the project language**
2. **Consult the language-specific row** for each constraint (C1-C15) you're applying
3. **Follow the language-appropriate pattern** rather than the generic recommendation
4. **When multi-language** (e.g., Java backend + TypeScript frontend), apply the appropriate adaptation per layer
