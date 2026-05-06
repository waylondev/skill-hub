# Pre-Generation Checklist — Detailed Reference

## Purpose

This checklist replaces the post-generation self-calibration rubric with **proactive quality gates**. Apply it **before** generating code to prevent quality issues rather than fixing them afterward.

**CRITICAL**: Before applying this checklist, ALL Architecture Gates (G0-G7) from `architectural-gates.md` MUST pass.
Architecture gates are checked FIRST — if any gate fails, redesign before proceeding to P0/P1/P2 checks.

---

## Execution Protocol

The checklist is executed in THREE phases:

### Phase 1: Gate Declaration (BEFORE generating code)

AI MUST output the Gate Declaration block (see `architectural-gates.md` format) declaring:
- Context profile (G0)
- Layer boundaries (G1)
- TOCTOU prevention strategy (G2)
- Idempotency strategy (G3)
- Security entry points (G4)
- Aggregate invariant enforcement (G5)
- Projection query strategy (G6)
- Config externalization mechanism (G7)

**This is a commitment — the generated code MUST match the declaration.**

### Phase 2: Code Generation

Generate code according to the declared gates. If the design changes during generation, update the declaration.

### Phase 3: Post-Generation Review (AFTER generating code)

AI MUST scan its own output and output the Post-Generation Review block, checking each gate against the actual code:
- ✓ means the gate is satisfied
- ✗ means the gate is violated — AI MUST fix the violating code and re-review

---

## Architecture Gate Audit (MUST PASS BEFORE P0)

| Gate | Check | Tool |
|------|-------|------|
| G0: Context Profile | Determined project context (MVP/Scale-Up/Enterprise)? | `context-branching.md` |
| G1: Layer Architecture | Service returns domain objects? Controller returns DTOs? Dedicated Mapper? No entity leak? No HTTP types in Service? | `architectural-gates.md` §Gate 1 |
| G2: TOCTOU Prevention | No check-then-act? Atomic patterns (unique constraint + catch, UPSERT, FOR UPDATE)? | `architectural-gates.md` §Gate 2 |
| G3: Idempotency | POST requires `Idempotency-Key` header? No auto-UUID fallback? | `architectural-gates.md` §Gate 3 |
| G4: Security Entry Points | Spring Security entry points configured? Global handler has catch-all? No stack trace leaks? | `architectural-gates.md` §Gate 4 |
| G5: Aggregate Invariants | Business rules in domain objects? Service calls aggregate methods, not direct field mutation? | `architectural-gates.md` §Gate 5 |
| G6: Projection Queries | List/detail endpoints use DTO projections (SELECT new ...)? No entity loading + Service mapping? | `architectural-gates.md` §Gate 6 |
| G7: Config Externalization | Zero hardcoded URLs/credentials? All env-dependent values use `${ENV_VAR:default}`? | `architectural-gates.md` §Gate 7 |

**If ANY gate above fails: STOP. Redesign. Re-evaluate gates. Do NOT proceed to P0.**

---

## P0 — Must Pass (Non-Negotiable)

Every code generation MUST satisfy these. No exceptions.

### C1: Input Validation at Boundary

**Check**: Are ALL external inputs validated at the entry point?

**What counts as external input**:
- HTTP request bodies, query parameters, headers, path variables
- Message queue payloads (Kafka, RabbitMQ)
- File uploads, form data
- Database results from external systems (legacy integrations)
- Environment variables, configuration values
- Results from external API calls

**Validation strategy by input type**:

| Input Type | Validation |
|------------|-----------|
| User input (forms, API) | Schema validation (Bean Validation, Zod, Pydantic) |
| ID/UUID | Format check + existence verification |
| Numeric | Range validation (min, max, positive, non-zero) |
| String | Length, pattern, allowed characters |
| Collection | Empty check, max size, element validation |
| File | Type/extension, max size, virus scan (if user-uploaded) |

**Example**:
```java
// ✅ Validated at controller boundary
@PostMapping("/users")
public UserDto createUser(@Valid @RequestBody CreateUserRequest req) {
    // req has been validated: email format, password strength, name length
    return userService.create(req);
}
```

### C2: No Silent Failures

**Check**: Does every failure path have an explicit strategy?

**Explicit strategies** (pick one per failure point):
1. **Throw** — for unrecoverable errors that the caller should handle
2. **Return Result** — for expected failures with multiple outcomes (see DT-4)
3. **Log + Recover** — for non-critical failures where degradation is acceptable
4. **Retry** — for transient failures with backoff (see `patterns.md` Retry pattern)

**Never do this**:
```java
// ❌ Silent failure — no strategy
try { operation(); } catch (Exception e) { /* nothing */ }
// ❌ Log only, no recovery
try { operation(); } catch (Exception e) { log.error("failed", e); } // continues as if succeeded
```

### C6: Security by Default

**Check**: Is the code secure by construction, not by patching?

**Mandatory checks**:
- [ ] SQL: parameterized queries only (no string concatenation)
- [ ] XSS: output encoding for user-controlled data in HTML
- [ ] Secrets: no hardcoded passwords, API keys, tokens in source
- [ ] Authz: authorization check at service layer (not just controller)
- [ ] CSRF: CSRF tokens for state-changing operations (if session-based auth)
- [ ] Deserialization: never deserialize untrusted data without schema validation

### C8: Method Length ≤ 60 Lines

**Check**: Do any methods exceed 60 lines (language-specific limits apply)?

**Language-specific limits** (see `context-branching.md`):
- Java: ≤ 60 lines
- Kotlin: ≤ 40 lines
- Go: ≤ 50 lines
- Python: ≤ 40 lines
- TypeScript: ≤ 50 lines

**If a method exceeds the limit**:
1. Extract cohesive sub-operations into well-named methods
2. Each extracted method should operate at a single abstraction level
3. The parent method should read like a story (sequence of named steps)

### C9: Atomicity Guarantee

**Check**: Do multi-step mutations complete all-or-nothing?

**Atomicity patterns**:
- **Single database**: `@Transactional` or explicit transaction
- **Multiple databases**: Outbox pattern (write event + data in same TX)
- **Multiple services**: Saga with compensating actions
- **File operations**: Write to temp file → atomic rename
- **Configuration**: Expand-contract migration (never destructive single-step)

---

## P1 — Context-Dependent

Apply based on project context. Skip only if explicitly justified.

### C10: Idempotency

**Apply when**: Any state-changing operation that may be retried.

**Skip when**: Read-only operations, GET endpoints, pure functions.

**Implementation**:
- HTTP: `Idempotency-Key` header + deduplication store
- Message: Message ID tracking in processed messages table
- Database: Unique constraint on business key (natural idempotency)
- Distributed: Optimistic lock with version number

### C11: Observability Built-in

**Apply when**: Scale-Up, Enterprise, Critical Infra contexts.

**Skip when**: Startup MVP (add when first production incident occurs).

**Minimum observability**:
- Structured logging (JSON) with trace ID
- Error rate metric on all public endpoints
- Health check endpoint exposing critical dependencies
- Key business events logged (user created, order placed, payment processed)

### C12: Configuration Externalization

**Apply when**: Code will run in multiple environments.

**Never hardcode**:
- Database URLs, connection strings
- API endpoints (use environment-specific config)
- Feature toggle values (use config service)
- Rate limits, timeouts, retry counts

**OK to hardcode**:
- Default values that are valid for any environment
- Protocol constants (e.g., `HTTPS`)
- Algorithm parameters that are part of business logic

### C13: Backward Compatibility

**Apply when**: API is consumed by external clients or other teams.

**Skip when**: Greenfield internal service, same-team frontend/backend.

**Backward-compatible changes**:
- Add optional fields (with defaults)
- Add new endpoints (don't modify existing)
- Deprecate fields before removing (mark + document timeline)

**Breaking changes** (require version bump):
- Remove fields
- Change field types
- Rename fields
- Change error response format

### C15: Dependency Minimalism

**Check**: Is every new dependency justified?

**Before adding a dependency, ask**:
1. Can the standard library do this? (Go's stdlib, Python's stdlib)
2. Is the dependency actively maintained? (check last commit, issue count)
3. Does it introduce security vulnerabilities? (check CVE database)
4. Is there a lighter alternative? (compare bundle size, transitive deps)
5. Is this functionality needed in production, or only for testing?

---

## P2 — Documentation

### C4: Explain Non-Obvious Decisions

**Check**: Are surprising choices documented with "why"?

**What needs explanation**:
- Choosing a less popular library over a popular one
- Accepting a known limitation/short-cut
- Deviating from team conventions
- Workarounds for third-party bugs

**What doesn't need explanation**:
- Standard patterns (Repository, Factory, Strategy)
- Language idioms (idiomatic code is self-documenting)
- Obvious business rules (should be clear from method name)

### C14: Documentation Sync

**Apply when**: Architectural decisions are made.

**Required artifacts**:
- ADR (Architecture Decision Record) for major technology choices
- OpenAPI/Protobuf schema update when API contract changes
- README update when new setup steps are required
- Migration guide when upgrading breaking dependencies

### C3: Always Include Tests

**Minimum test set**:
- **Happy path**: The primary use case succeeds
- **Error path**: At least one failure scenario is tested
- **Edge case**: Boundary condition (empty input, max input, null)

**Test strategy by context** (see `context-branching.md`):

| Context | Minimum Coverage |
|---------|-----------------|
| Startup MVP | Critical paths only (~40%) |
| Scale-Up | Core domain 80%+ |
| Enterprise | 90%+ branch coverage |
| Critical Infra | 95%+ with mutation testing |

---

## Scoring Rules

### Weighted Score Calculation

| Category | Weight | Threshold |
|----------|--------|-----------|
| **Correctness** | 25% | All requirements met, no logical flaws |
| **Security** | 25% | Input validated, no injection risks, secrets protected |
| **Testability** | 15% | Dependencies injectable, side effects isolated |
| **Observability** | 15% | Metrics, structured logs, error tracing |
| **Performance** | 10% | No N+1 queries, resource-efficient |
| **Maintainability** | 10% | Clear naming, SRP, method length discipline |

### Passing Criteria

| Context | Minimum Score |
|---------|--------------|
| **Startup MVP** | ≥ 75 (P0 must pass, P1 can be partial) |
| **Scale-Up** | ≥ 85 (P0 must pass, P1 must pass for applicable items) |
| **Enterprise** | ≥ 90 (All P0 + applicable P1 must pass) |
| **Critical Infra** | ≥ 95 (All P0 + P1 + P2 must pass) |

### Iteration Process

1. Generate code
2. Score against rubric
3. If score < threshold:
   a. Identify weakest categories
   b. Redesign those aspects
   c. Re-score
4. Maximum 3 iterations; if still below threshold, document trade-offs and proceed with explicit warnings
