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
