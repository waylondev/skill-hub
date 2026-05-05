---
name: code-excellence
description: >
  Universal programming excellence skill. Transforms LLM code output from
  "correct" to "expert-level" through pattern catalogs, decision trees,
  anti-pattern recognition, context-aware adaptation strategies, and
  mandatory generation constraints that prevent simplified "just works" code.
metadata:
  version: 3.0.0
  category: foundation
  priority: high
  language_agnostic: true
triggers:
  - code_generation
  - code_review
  - refactoring
  - architecture_design
  - debugging
  - user_mentions_best_practices_or_principles
references:
  - patterns.md
  - patterns-crud.md
  - anti-patterns.md
  - decision-trees.md
  - context-branching.md
  - review-template.md
  - testing-patterns.md
  - java.md
  - kotlin.md
  - golang.md
  - python.md
  - springboot.md
---

# Code Excellence v3

## How LLMs Should Use This Skill

This is not a principles document to read passively. It is an **operating system for code generation**.
Use it as follows:

### Generation Pipeline
```
User Request → [context-branching.md] → Determine context profile
             → [decision-trees.md]    → Identify applicable patterns
             → [patterns.md] /        → Select implementation template
                [patterns-crud.md]
             → [anti-patterns.md]     → Avoid known traps
             → [lang-ref]             → Apply language idioms
             → [Generation Constraints below] → Apply quality gates
             → Generate code
```

### Review Pipeline
```
Generated Code → [review-template.md]   → Structured review
              → [anti-patterns.md]      → Scan for anti-patterns
              → [decision-trees.md]     → Verify decisions match context
              → [patterns.md]           → Check pattern implementation fidelity
              → Flag issues or approve
```

### When to Consult Which File

| Situation | Primary Reference | Secondary |
|-----------|-------------------|-----------|
| Writing new code | `decision-trees.md` → `patterns.md` / `patterns-crud.md` | `anti-patterns.md` |
| Reviewing code | `review-template.md` → `anti-patterns.md` | `decision-trees.md` |
| Choosing architecture | `context-branching.md` | `decision-trees.md` |
| Refactoring | `anti-patterns.md` → `patterns.md` | `context-branching.md` |
| Debugging | `anti-patterns.md` (symptom→root cause) | `decision-trees.md` |
| Writing tests | `testing-patterns.md` | `context-branching.md` |
| Language/framework specifics | `java.md` / `kotlin.md` / `golang.md` / `python.md` / `springboot.md` | — |

---

## Generation Constraints (MANDATORY)

When generating code, these constraints are **NOT optional**. They are the difference between
"working code" and "production-ready code". Every piece of generated code MUST satisfy all applicable constraints:

### Constraint 1: Input Validation at the Boundary
Every public method that accepts external input (user request, file, network, config)
MUST validate at the entry point. Reject invalid input immediately with a specific error.

```
// DO: validate before any business logic
if (userId == null || userId <= 0) throw new InvalidRequestException("userId must be positive");
if (items.isEmpty()) throw new InvalidRequestException("at least one item required");

// DON'T: silently handle or let it fail deep inside
```

### Constraint 2: No Silent Failures
Every code path that can fail MUST have an explicit error handling strategy. The three options are:
1. **Throw** — let it propagate to the global error handler (for technical/unrecoverable errors)
2. **Return Result type** — for expected business failures the caller should handle
3. **Log + recover** — ONLY for non-critical failures where the main flow can continue

```
// DON'T: empty catch or swallow
try { cache.set(key, value); } catch (Exception ignored) {}

// DO: observe and proceed
try { cache.set(key, value); }
catch (Exception e) { metrics.cacheWriteFail.increment();
                       log.warn("Cache write failed for {}", key, e); }
```

### Constraint 3: Always Include Tests
Every generated feature MUST include at least one test. The test should cover:
- **Happy path**: the normal expected flow
- **Error path**: at least one failure scenario
- **Edge case**: null, empty, boundary value

### Constraint 4: Explain Non-Obvious Decisions
Every code choice that a reader might question MUST have a comment explaining the "why":
```
// We use REQUIRES_NEW here because the audit log must persist even
// if the outer transaction rolls back. This is the ONLY valid use case
// for REQUIRES_NEW in this codebase.
```

### Constraint 5: No Simplified "Demo" Code
Never generate code that:
- Uses `// ... rest of implementation` for core logic
- Skips error handling with `// handle error`
- Uses mock implementations for critical paths
- Assumes inputs are always valid
- Ignores resource cleanup
- Skips transaction management for data mutations
- Omits idempotency for side-effecting operations

### Constraint 6: Security by Default
Every generated code MUST:
- Escape or parameterize all user input that reaches a database
- Never log secrets, passwords, or tokens (even accidentally via toString)
- Validate authorization at the service layer, not just the controller
- Use parameterized queries / prepared statements (NEVER string concatenation for SQL)

### Constraint 7: Resource Cleanup
Every resource that is opened (file, connection, lock, stream) MUST have a deterministic
release strategy using language-specific constructs:
- Java: try-with-resources
- Go: defer
- Python: context manager (with)
- Kotlin: use / AutoCloseable

---

## Core Philosophy

The difference between correct code and expert code is **not** knowing more principles.
It is knowing:

1. **When to follow a principle and when to break it** — context sensitivity
2. **Which pattern to apply given ambiguous signals** — decision trees
3. **What failure looks like before it happens** — anti-pattern recognition
4. **How to leave room for unknown future change** — evolvability

### Principle Priority (for conflict resolution)

| Priority | Principle | Signal |
|----------|-----------|--------|
| 1 | **Correctness** | If it produces wrong output, nothing else matters |
| 2 | **Safety** | No data loss, no security breach, no silent corruption |
| 3 | **Simplicity (KISS)** | Could this be understood in 6 months by someone else? |
| 4 | **Evolvability** | Will the next likely change require touching 1 file or 20? |
| 5 | **Consistency** | Does this follow the patterns already established in the codebase? |
| 6 | **DRY** | Extract only when two pieces share the same reason to change |

---

## Quick Expert Checklist

Before finalizing any generated code, verify:

**Structure**
- [ ] Each class has one reason to change? (Describe it without "and"/"or")
- [ ] Dependency direction points toward stable abstractions?
- [ ] New code extends rather than modifies existing tested code?

**Robustness**
- [ ] Every external input validated at the boundary? (Constraint 1)
- [ ] Error messages contain enough context to diagnose without reading code? (Constraint 2)
- [ ] Idempotency guaranteed for non-idempotent operations that can be retried?

**Performance awareness**
- [ ] N+1 queries impossible on this code path?
- [ ] Resources (connections, files, locks) released deterministically? (Constraint 7)
- [ ] No premature optimization without profiler evidence?

**Production readiness**
- [ ] Secrets absent from source code and logs? (Constraint 6)
- [ ] Health check exposes critical dependency status?
- [ ] Feature toggles exist for risky changes?

---

## Limitations

- This skill encodes **transferable expertise patterns**, not exhaustive domain knowledge.
  Domain-specific patterns (e.g., fintech settlement, healthcare FHIR) belong in separate skills.
- The goal is **pragmatic mastery**, not academic perfection.
- All rules have exceptions. The skill teaches you how to *recognize* valid exceptions,
  not to blindly follow rules.

---

## Version History

- **3.0.0** — Added mandatory Generation Constraints (7 rules), testing patterns, review template,
  CRUD patterns, multi-language anti-patterns. Architecture-level additions.
- **2.0.0** — Structural transformation: pattern catalog, anti-pattern library, decision trees,
  context-branching. Upgraded all language references with deep expertise content.
- **1.1.0** — Added principle priority, anti‑patterns, quick checklist, API design, immutability,
  trigger conditions, decoupled language/framework references.
- **1.0.0** — Initial release.
