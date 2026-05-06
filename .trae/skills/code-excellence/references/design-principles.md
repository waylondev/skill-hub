# Core Design Principles

## Purpose

These principles form the bedrock of production-grade code. They apply universally
across languages and frameworks. When you face an ambiguous design choice, consult
these principles first — then use `decision-trees.md` for concrete direction.

---

## 1. Composition Over Inheritance

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

---

## 2. Modularity

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

---

## 3. Single Responsibility at Every Level

| Level | Rule | Anti-Pattern |
|-------|------|-------------|
| **System** | One business domain | Monolith doing CRM + ERP + CMS |
| **Service** | One business capability | OrderService that also sends emails and generates PDFs |
| **Method** | One level of abstraction, one thing well | 200-line method mixing validation + business logic + persistence + logging |
| **Class** | Describe without "and" / "or" | UserAndPermissionManager |

---

## 4. Short Methods

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

---

## 5. Atomicity

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

---

## 6. Idempotency

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

---

## 7. Immutability-First

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

---

## 8. Fail Fast

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

---

## 9. Principle of Least Astonishment

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

---

## 10. Explicit Over Implicit

Behavior that is not obvious from the signature should be replaced by behavior that is.

- **Named parameters** over positional ambiguity
- **Typed wrappers** over primitives (UserId vs Long, Email vs String)
- **Explanatory variables** over complex inline expressions
- **Avoid magic** (reflection, monkey-patching, AOP without clear convention)

---

## Principle Priority (for conflict resolution)

When principles conflict, follow this priority chain:

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

## How to Use This Reference

1. When facing a design choice, first identify which principles are relevant
2. If principles conflict, use the priority table above
3. For concrete implementation decisions, consult `decision-trees.md`
4. For detecting violations in existing code, cross-reference with `anti-patterns.md`
