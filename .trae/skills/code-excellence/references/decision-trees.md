# Decision Trees

## Purpose

Signal-driven decision guides. When you encounter a code design choice,
trace through the tree to reach the expert recommendation.

---

## DT-1: Interface or Not?

```
Do you have multiple implementations TODAY?
├── YES → Create interface
│   └── Is the interface consumed in a different package/module?
│       ├── YES → Define interface in consumer's package (ISP)
│       └── NO  → Define interface near implementations
└── NO  → Do you need to mock this for testing?
    ├── YES → Is the class final or does it have side-effect constructors?
    │   ├── YES → Extract interface
    │   └── NO  → Mock the class directly. No interface needed.
    └── NO  → No interface. YAGNI.
        └── Exception: Library code consumed by external teams → interface upfront
```

---

## DT-2: Record / Data Class vs Regular Class

```
Does this type primarily carry data (no significant behavior)?
├── YES → Is it:
│   ├── A JPA @Entity?            → Regular class (Hibernate proxy issues)
│   ├── A config property holder?  → Record (Java) / data class (Kotlin)
│   ├── An API DTO?                → Record (Java) / data class (Kotlin)
│   ├── A value object (Money, Email, PhoneNumber)?
│   │   ├── Needs validation in constructor? → Regular class with validation
│   │   └── Pure data carrier?               → Record / data class
│   └── A domain entity with behavior? → Regular class (model the behavior)
└── NO  → Regular class
```

---

## DT-3: Stream / Functional Pipeline vs For Loop

```
Is the transformation a simple filter-map-collect chain?
├── YES → Stream (Java) / Collection pipeline (Kotlin) / Comprehension (Python)
└── NO  → Does the logic involve:
    ├── Checked exceptions?                    → For loop
    ├── Multiple mutable accumulators?         → For loop
    ├── Complex branching (>3 conditions)?     → Consider for loop
    ├── Early exit / break?                    → For loop (or takeWhile)
    └── Nested operations with dependencies?   → For loop
```

**Expert rule of thumb**: If you have to scroll to see the entire stream pipeline, extract methods or use a loop.

---

## DT-4: Exception vs Result Type

```
Can the caller meaningfully handle this failure?
├── YES → Is there more than one distinct failure mode?
│   ├── YES → Result type (sealed class / union type)
│   └── NO  → Optional or simple boolean
└── NO  → Exception (let it propagate to the global error handler)

Is this truly exceptional (programmer error, infrastructure failure)?
├── YES → Exception (IllegalArgumentException, ConnectionException)
└── NO  → Result type (validation, not-found, business rule violation)
```

---

## DT-5: Synchronous vs Asynchronous

```
Is this I/O-bound (network, disk, database)?
├── YES → Is the caller already in an async context?
│   ├── YES → Async (CompletableFuture / suspend / async def)
│   └── NO  → Consider: does this code path serve concurrent users?
│       ├── YES and throughput matters → Use async or virtual threads
│       └── NO or simple CRUD           → Synchronous is fine
└── NO (CPU-bound) → Synchronous. Never offload CPU work to async pools.
```

**Java 21 note**: With virtual threads, synchronous I/O code gets async-like throughput without async syntax. If using virtual threads throughout, prefer synchronous style for I/O.

---

## DT-6: Singleton / Static Utility vs Injected Dependency

```
Does this dependency need to change in tests?
├── YES → Inject it
└── NO  → Does it maintain state between calls?
    ├── YES → Inject it (stateful singletons are global mutable state)
    └── NO  → Is it a pure function with zero external dependencies?
        ├── YES → Static utility is fine (e.g., Math.max, StringUtils.capitalize)
        └── NO  → Inject it (if it touches I/O, clock, randomness, or config)
```

**The true test**: "Can I test code that calls this WITHOUT mocking anything?" If yes, static is okay.

---

## DT-7: @Transactional Propagation Strategy

```
Is the caller already in a transaction?
├── YES → Does this method need to COMMIT independently?
│   ├── YES → REQUIRES_NEW (audit logging, outbox events that must persist)
│   └── NO  → REQUIRED (join existing — the default and usually correct)
└── NO  → REQUIRED (start a new one)

Should this method EVER be called within a transaction?
├── NO → NEVER → throws if transaction exists
└── YES → default behavior
```

**Expert warning**: `REQUIRES_NEW` suspends the outer transaction. If the outer transaction rolls back after the inner committed, you have data inconsistency. Almost always the wrong choice outside of audit/outbox patterns.

---

## DT-8: Cache or Don't Cache

```
Is this data:
├── Read >> Write? (read 100x more than written)
│   ├── YES → Is eventual consistency acceptable?
│   │   ├── YES → Does it fit in memory?
│   │   │   ├── YES → Caffeine (local) or Redis (distributed)
│   │   │   └── NO  → Don't cache. Optimize the query instead.
│   │   └── NO (must be immediately consistent)
│   │       └── Don't cache. Use read replicas or database caching.
│   └── NO → Is the computation expensive (>100ms)?
│       ├── YES → Cache with short TTL and explicitly handle staleness
│       └── NO  → Don't cache. Premature caching adds invalidation complexity.
└── Write-heavy → Don't cache. Focus on write path optimization.
```

---

## DT-9: Monolith vs Microservices

```
Team size:
├── < 8 developers total           → Monolith. Modular monolith with package boundaries.
├── 8-30 developers, 2-3 domains   → Modular monolith + maybe 1-2 extracted services.
└── 30+ developers, 5+ domains     → Consider microservices.

Deployment needs:
├── Independent deploy of features → Extract that feature as a service.
├── All deploy together            → Stay monolithic.
└── Mixed → Strangler Fig: extract high-change services, leave stable parts in monolith.

Data consistency needs:
├── Strong consistency required across domains → Monolith (single DB transaction).
└── Eventually consistent is acceptable        → Microservices viable (Saga / Outbox).
```

---

## DT-10: Naming Decision

```
Function that returns a value:
├── Boolean   → isXxx, hasXxx, canXxx
├── Object    → getXxx, findXxx, createXxx
└── Collection → getXxxs, listXxxs, findXxxs

Function that performs an action:
├── Save/create/update → createXxx, updateXxx, saveXxx
├── Delete/remove      → deleteXxx, removeXxx
├── Process/transform  → processXxx, convertXxx, mapXxx
└── Validate/check     → validateXxx, checkXxx, ensureXxx

Variables:
├── Single entity   → user, order, payment (exactly what it is)
├── Collection      → users, pendingOrders, activePayments (plural)
├── Count/length    → userCount, itemCount (never just "count" or "num")
├── Boolean flag    → isActive, hasDiscount, canEdit (question form)
└── Configuration   → maxRetries, baseUrl, timeoutSeconds (descriptive)
```

---

## How to Use Decision Trees

When making a design choice during code generation:

1. Identify the decision category (interface, data type, error handling, etc.)
2. Trace the tree top to bottom using the actual context
3. Apply the recommended approach
4. If the tree recommends against a pattern you were about to use, **reconsider** — the tree encodes expert heuristics that prevent common mistakes
