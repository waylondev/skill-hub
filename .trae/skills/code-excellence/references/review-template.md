# Code Review Template

## Purpose

A structured, executable review template. When reviewing code (human or AI-generated),
follow this template exactly. Each section has a specific focus and produces actionable output.

---

## How to Use

1. Run through sections 1-6 in order
2. For each checkmark that FAILS, write a specific finding with:
   - **Location**: file + line number
   - **Issue**: what is wrong
   - **Severity**: CRITICAL / WARNING / SUGGESTION
   - **Fix**: concrete recommendation

---

## Section 1: Architecture Review

### Design Decision Verification
- [ ] Does the design follow an applicable decision tree from `decision-trees.md`?
  - If yes, which tree? (e.g., DT-1 Interface, DT-4 Exception vs Result)
  - If no, why was it skipped? (valid reason or oversight?)
- [ ] Are dependency directions correct? (controller → service → repository, never reverse)
- [ ] Would the next likely change touch 1 file or many? If many → SRP violation

### Context Alignment
- [ ] Does the complexity level match the context profile? (see `context-branching.md`)
  - Startup MVP: Simple, minimal abstractions
  - Enterprise: Full error taxonomy, observability, tests
- [ ] Is the chosen pattern appropriate for the domain? (not over-engineered, not under-designed)

---

## Section 2: Correctness Review

### Error Handling
- [ ] Are ALL error cases handled? (not just happy path)
- [ ] Are null/empty inputs validated at the boundary?
- [ ] Is there a race condition risk? (concurrent access to shared state)
- [ ] Can the operation be retried safely? (idempotency)
- [ ] Are error messages actionable? (can a human diagnose without reading source?)

### Data Integrity
- [ ] Are database mutations within a transaction boundary?
- [ ] Are constraints enforced? (unique, foreign key, not-null)
- [ ] Is optimistic/pessimistic locking used for concurrent updates?
- [ ] Are there orphan records risk? (parent deleted but children remain)

### Security
- [ ] All SQL uses parameterized queries? (NO string concatenation)
- [ ] User input sanitized before use? (XSS, injection)
- [ ] Authorization checked at service layer? (not just controller)
- [ ] No secrets in code or logs?
- [ ] Sensitive data not exposed in API response?

---

## Section 3: Anti-Pattern Scan

Scan for each anti-pattern in `anti-patterns.md`:

| Anti-Pattern | Found? | Location | Severity |
|-------------|--------|----------|----------|
| AP-1: God Class (>10 public methods) | ☐ | | |
| AP-2: Premature Abstraction (boolean flags) | ☐ | | |
| AP-3: Swallowed Exception | ☐ | | |
| AP-4: Entity Leaked to API | ☐ | | |
| AP-5: N+1 Queries | ☐ | | |
| AP-6: Mutable Static State | ☐ | | |
| AP-7: Magic Value | ☐ | | |
| AP-8: Missing Idempotency | ☐ | | |
| AP-9: Exception as Control Flow | ☐ | | |
| AP-10: Thread.sleep in Production | ☐ | | |
| AP-11: Ignored Error (Go) | ☐ | | |
| AP-12: God main.go (Go) | ☐ | | |
| AP-13: ORM Leak (Python) | ☐ | | |
| AP-14: Global Mutable State (Python) | ☐ | | |
| AP-15: Bare Except (Python) | ☐ | | |
| AP-16: Data Class Entity (Kotlin) | ☐ | | |

---

## Section 4: Production Readiness

### Observability
- [ ] Does the code log key business events? (order created, payment processed)
- [ ] Are logs structured? (JSON with traceId, not string concatenation)
- [ ] Are metrics exposed for critical paths? (latency, error rate, throughput)

### Performance
- [ ] Is there an N+1 query risk? (loop with DB call inside)
- [ ] Are resources released deterministically? (try-with-resources, defer, with)
- [ ] Is pagination applied to list endpoints?
- [ ] Are expensive operations cached? (only if profiling justifies it)

### Resilience
- [ ] External service calls have timeout? (never infinite wait)
- [ ] External service calls have retry/backoff? (not infinite retries)
- [ ] Critical POST operations have idempotency?
- [ ] Feature toggle for risky changes?

---

## Section 5: Test Coverage

### Test Existence
- [ ] Happy path test exists?
- [ ] Error path test exists? (at least one failure scenario)
- [ ] Edge case test exists? (null, empty, boundary)

### Test Quality
- [ ] Tests verify BEHAVIOUR, not implementation? (no testing private methods)
- [ ] Tests are independent? (order of test execution doesn't matter)
- [ ] Tests use realistic data? (not `test`/`foo`/`bar` everywhere)
- [ ] Tests cover the error handling paths? (not just success)

---

## Section 6: Security Review

- [ ] Run through Quick Security Checklist in `security-patterns.md`
- [ ] JWT tokens properly managed? (short expiry, refresh rotation, secure storage)
- [ ] RBAC/ABAC authorization at service layer? (not just controller guard)
- [ ] Audit trail exists for all data mutations?
- [ ] Rate limiting on critical endpoints? (auth, payment, API mutations)
- [ ] OWASP Top 10 risks addressed? (injection, XSS, broken access control)
- [ ] Defense in depth applied? (all 7 layers validated)

---

## Output Format

```
## Code Review: [Component Name]

### CRITICAL Issues (must fix before merge)
1. [AP-3] `OrderService.java:42` — Swallowed exception: `catch (PaymentException e) { log.error("..."); }` without rethrow or recovery. Order proceeds as unpaid.
   Fix: `throw new PaymentFailedException(...)`

### WARNING Issues (should fix)
1. [AP-5] `OrderController.java:28` — N+1: stream calls `paymentRepo.findByOrderId()` per iteration.
   Fix: Batch fetch or JOIN FETCH.

### SUGGESTIONS (nice to have)
1. `OrderService.java:15` — Consider extracting `validateOrder()` method. Currently 40 lines in `create()`.
```

---

## Review Decision

```
APPROVED — No CRITICAL issues, ≤ 2 WARNINGs, all SUGGESTIONS noted
CONDITIONAL — WARNINGs exist but non-blocking, SUGGESTIONS accepted
REJECTED   — CRITICAL issues exist, or too many WARNINGs
```
