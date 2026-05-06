# Code Excellence v4

## How LLMs Should Use This Skill

This is not a principles document to read passively. It is an **operating system for code generation**.
Use it as follows:

### Generation Pipeline
```
User Request → [context-branching.md] → Determine context profile
             → [decision-trees.md]    → Identify applicable patterns
             → [patterns.md] /        → Select implementation template
                [patterns-crud.md] /
                [patterns-architecture.md]
             → [anti-patterns.md]     → Avoid known traps
             → [security-patterns.md] → Apply security by design
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

### Refactoring Pipeline
```
Legacy/Target Code → [context-branching.md] → Reassess context (may have shifted)
                   → [anti-patterns.md]     → Identify root cause, not symptom
                   → [decision-trees.md]    → Choose target pattern
                   → [patterns-architecture.md] → Architecture-level restructuring
                   → [patterns.md]          → Apply pattern incrementally
                   → Apply Strangler Fig for safe migration
```

### Debugging Pipeline
```
Production Issue → [anti-patterns.md]     → Symptom → Root Cause matching
                → [security-patterns.md]  → Rule out security incidents first
                → [decision-trees.md]     → Verify original architectural decisions
                → [review-template.md]    → Targeted focused review of affected area
                → Fix + add regression test
```

### When to Consult Which File

| Situation | Primary Reference | Secondary |
|-----------|-------------------|-----------|
| Writing new code | `decision-trees.md` → `patterns.md` / `patterns-crud.md` | `anti-patterns.md` |
| Reviewing code | `review-template.md` → `anti-patterns.md` | `decision-trees.md` |
| Choosing architecture | `context-branching.md` → `patterns-architecture.md` | `decision-trees.md` |
| Refactoring | `anti-patterns.md` → `patterns.md` | `context-branching.md` |
| Debugging | `anti-patterns.md` (symptom→root cause) | `security-patterns.md` |
| Writing tests | `testing-patterns.md` | `context-branching.md` |
| Security review | `security-patterns.md` | `anti-patterns.md` |
| Language/framework specifics | `java.md` / `kotlin.md` / `golang.md` / `python.md` / `springboot.md` | — |

---

## Core Design Principles

These principles form the bedrock of production-grade code. They apply universally across languages and frameworks.

### 1. Composition Over Inheritance

Inheritance creates rigid hierarchies that are hard to change. Composition creates flexible collaborations that can evolve.

```
Prefer "has-a" over "is-a" unless the relationship is truly a subtype.
```

```java
// ❌ Inheritance — rigid, fragile base class problem
class AuditLogger extends FileLogger {
    // inherits everything from FileLogger, even stuff we don't need
}

// ✅ Composition — flexible, explicit delegation
class AuditLogger {
    private final LogWriter writer;
    private final Clock clock;

    public void log(Event e) {
        writer.write(LogEntry.of(e, clock.instant()));
    }
}
```

**When inheritance IS okay**: Implementing interfaces/sealed types, framework base classes where you control both sides, and truly stable "is-a" relationships.

### 2. Modularity

Every module/package/component must have a single, well-defined responsibility with explicit boundaries.

- **High cohesion within modules**: Things that change together live together
- **Low coupling between modules**: Depend on abstractions, not implementations
- **Explicit public API**: What's not exported should not be used

```java
// Module boundary using Java's module system (JPMS) or package-private
module com.example.orders {
    exports com.example.orders.api;      // Public contract
    requires com.example.payments.api;   // Explicit dependency
    // Everything else is encapsulated
}
```

### 3. Single Responsibility at Every Level

| Level | Rule | Anti-Pattern |
|-------|------|-------------|
| **System** | One business domain | Monolith doing CRM + ERP + CMS |
| **Service** | One business capability | OrderService that also sends emails and generates PDFs |
| **Method** | One level of abstraction, one thing well | 200-line method mixing validation + business logic + persistence + logging |
| **Class** | Describe without "and" / "or" | UserAndPermissionManager |

### 4. Short Methods

A method should do one thing, operate at a single level of abstraction, and fit on screen.

```
Method length signals:
  < 20 lines — excellent, reads like a story
  20-40 lines — acceptable if coherent
  40-80 lines — extract sub-operations into named methods
  > 80 lines — almost certainly a God Method, refactor
```

```java
// ❌ Monolithic method mixing abstraction levels
public OrderResult placeOrder(OrderRequest req) {
    // 15 lines of validation
    // 20 lines of payment processing
    // 10 lines of inventory update
    // 15 lines of notification
    // 10 lines of response building
    return result; // 70+ lines total
}

// ✅ Each step at a consistent abstraction level
public OrderResult placeOrder(OrderRequest req) {
    validateOrder(req);
    var payment = capturePayment(req.payment());
    var reservation = reserveInventory(req.items());
    notifyCustomer(req.userId());
    return buildResult(payment, reservation);
}
```

### 5. Atomicity

An operation must either complete entirely or have zero effect. Partial completion is corruption.

```
Atomicity = All-or-Nothing
```

- **Database**: Use transactions. Never commit half the changes.
- **Distributed**: Use Saga with compensating actions for multi-service operations.
- **File operations**: Write to temp file → atomic rename. Never write in-place.
- **Configuration changes**: Use expand-contract. Never destructive single-step migration.

```java
// ✅ Atomic file write
Files.writeString(tempPath, content);
Files.move(tempPath, targetPath, ATOMIC_MOVE, REPLACE_EXISTING);
// If crash happens before move → temp file deleted on restart. Target untouched.

// ❌ Non-atomic file write
Files.writeString(targetPath, content);
// If crash happens mid-write → corrupted file, no recovery.
```

### 6. Idempotency

An operation, when applied multiple times, produces the same result as when applied once.

```
f(f(x)) = f(x)
```

| Operation | Idempotent? | Strategy if NOT |
|-----------|-------------|-----------------|
| GET / READ | ✅ naturally | — |
| PUT (full replace) | ✅ naturally | — |
| DELETE | ✅ naturally | — |
| POST (create) | ❌ | Idempotency key header |
| PATCH (partial) | ❌ | Conditional update with version/ETag |
| Payment charge | ❌ | Deduplication by idempotency key |
| Email send | ❌ | Exactly-once delivery via idempotency key |

### 7. Immutability-First

Prefer immutable data structures. Mutation is the root of concurrency bugs and unexpected side effects.

```java
// ✅ Immutable — safe to share, no synchronization needed
record Order(Long id, Status status, List<Item> items) {}

// ✅ Defensive copy when receiving mutable input
public Order(List<Item> items) {
    this.items = List.copyOf(items); // unmodifiable snapshot
}

// ❌ Mutable — thread-unsafe, can be modified by any holder
class Order {
    private List<Item> items; // anyone can add/remove
    public List<Item> getItems() { return items; } // raw reference leaked
}
```

### 8. Fail Fast

Detect invalid state immediately. Do not propagate bad data through the system.

```java
// ✅ Constructor validates immediately
public Order(Long userId, List<Item> items) {
    if (userId == null || userId <= 0) throw new IllegalArgumentException("userId required");
    if (items == null || items.isEmpty()) throw new IllegalArgumentException("items required");
    this.userId = userId;
    this.items = List.copyOf(items);
}

// ❌ Validation deferred — bad data spreads
public Order(Long userId, List<Item> items) {
    this.userId = userId; // null accepted
    this.items = items;   // empty list accepted
}
```

### 9. Principle of Least Astonishment

Code should behave exactly as a reasonable reader would expect from its name and context.

```java
// ❌ getById returns null sometimes, throws other times — inconsistent
public User getById(Long id) {
    if (id < 0) throw new IllegalArgumentException();
    return repo.findById(id).orElse(null);
}

// ✅ Convention: getXxx throws, findXxx returns Optional
public User getById(Long id) { return repo.findById(id).orElseThrow(); }
public Optional<User> findById(Long id) { return repo.findById(id); }
```

### 10. Explicit Over Implicit

Behavior that is not obvious from the signature should be replaced by behavior that is.

- **Named parameters** over positional ambiguity
- **Typed wrappers** over primitives (UserId vs Long, Email vs String)
- **Explanatory variables** over complex inline expressions
- **Avoid magic** (reflection, monkey-patching, AOP without clear convention)

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

### Constraint 8: Method Length Discipline
No method shall exceed 60 lines. If a method approaches this limit, extract sub-operations
into well-named private methods. Each method must operate at a single level of abstraction.

### Constraint 9: Atomicity Guarantee
Any operation that mutates state (database, file, configuration) MUST be atomic:
- Database mutations → within a transaction boundary
- Multi-service mutations → Saga with compensating actions
- File operations → write-to-temp + atomic rename
- Never leave the system in a partially-updated state after a failure

### Constraint 10: Idempotency for Side-Effecting Operations
Every non-read operation that can be retried (POST, PUT with side effects, payment, email)
MUST implement idempotency. The standard approach is an Idempotency-Key header.

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
| 3 | **Atomicity** | No partial state. All-or-nothing. |
| 4 | **Idempotency** | Repeated execution must produce the same result |
| 5 | **Simplicity (KISS)** | Could this be understood in 6 months by someone else? |
| 6 | **Evolvability** | Will the next likely change require touching 1 file or 20? |
| 7 | **Consistency** | Does this follow the patterns already established in the codebase? |
| 8 | **DRY** | Extract only when two pieces share the same reason to change |

---

## Quick Expert Checklist

Before finalizing any generated code, verify:

**Structure**
- [ ] Each class has one reason to change? (Describe it without "and"/"or")
- [ ] Dependency direction points toward stable abstractions?
- [ ] New code extends rather than modifies existing tested code?
- [ ] Inheritance used only where truly appropriate? (Prefer composition)
- [ ] Module boundaries explicit and respected?

**Robustness**
- [ ] Every external input validated at the boundary? (Constraint 1)
- [ ] Error messages contain enough context to diagnose without reading code? (Constraint 2)
- [ ] Idempotency guaranteed for non-idempotent operations that can be retried? (Constraint 10)
- [ ] Atomicity guaranteed for all multi-step mutations? (Constraint 9)
- [ ] No method exceeds 60 lines? (Constraint 8)

**Performance awareness**
- [ ] N+1 queries impossible on this code path?
- [ ] Resources (connections, files, locks) released deterministically? (Constraint 7)
- [ ] No premature optimization without profiler evidence?
- [ ] Immutable data structures used where possible?

**Production readiness**
- [ ] Secrets absent from source code and logs? (Constraint 6)
- [ ] Health check exposes critical dependency status?
- [ ] Feature toggles exist for risky changes?
- [ ] Security review passed against `security-patterns.md`?

---

## Limitations

- This skill encodes **transferable expertise patterns**, not exhaustive domain knowledge.
  Domain-specific patterns (e.g., fintech settlement, healthcare FHIR) belong in separate skills.
- The goal is **pragmatic mastery**, not academic perfection.
- All rules have exceptions. The skill teaches you how to *recognize* valid exceptions,
  not to blindly follow rules.

---

## Version History

- **4.0.0** — Added 10 Core Design Principles (Composition over Inheritance, Modularity, Short Methods, Atomicity, Idempotency, Immutability-First, Fail Fast, Least Astonishment, Explicit over Implicit). Added 3 new Generation Constraints (8: Method Length, 9: Atomicity, 10: Idempotency). Added Refactoring Pipeline, Debugging Pipeline. Added security-patterns.md, patterns-architecture.md references. Added decision trees DT-11~20. Added anti-patterns AP-17~27.
- **3.0.0** — Added mandatory Generation Constraints (7 rules), testing patterns, review template,
  CRUD patterns, multi-language anti-patterns. Architecture-level additions.
- **2.0.0** — Structural transformation: pattern catalog, anti-pattern library, decision trees,
  context-branching. Upgraded all language references with deep expertise content.
- **1.1.0** — Added principle priority, anti‑patterns, quick checklist, API design, immutability,
  trigger conditions, decoupled language/framework references.
- **1.0.0** — Initial release.
