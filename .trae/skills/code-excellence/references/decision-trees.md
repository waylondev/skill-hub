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

## DT-11: REST vs GraphQL vs gRPC

```
Client needs:
├── Web browser or public API?
│   ├── Mobile app with bandwidth constraints? → GraphQL (query only what you need)
│   ├── Public API for third-party developers?  → REST (universal, cacheable, discoverable)
│   └── Internal SPA? → REST with OpenAPI spec
├── Service-to-service (internal microservices)?
│   ├── High throughput, low latency required?      → gRPC (Protobuf, HTTP/2, streaming)
│   ├── Simple request-response, debugging matters? → REST (human-readable, curl-friendly)
│   └── Complex data graph with variable depth?     → GraphQL
└── Need real-time bidirectional streaming?
    └── gRPC (native bidirectional streaming) or WebSocket for browser clients

Data shape:
├── Fixed, well-known resource shapes              → REST
├── Highly variable, client-driven data needs       → GraphQL
├── Binary, schema-contract-driven                  → gRPC
└── Mixed → BFF pattern: GraphQL for web, gRPC between services, REST for public
```

---

## DT-12: SQL vs NoSQL

```
Data model:
├── Structured, relational, JOIN-heavy?
│   └── SQL (PostgreSQL, MySQL)
├── Document-oriented, flexible schema, nested?
│   ├── Need ACID transactions?      → PostgreSQL with JSONB (best of both)
│   └── Eventually consistent is OK?  → MongoDB
├── Key-value, simple GET/SET, high throughput?
│   └── Redis, DynamoDB
├── Time-series, append-only, high write volume?
│   └── TimescaleDB (SQL) or InfluxDB
├── Graph relationships (social networks, recommendations)?
│   └── Neo4j, PostgreSQL with recursive CTEs for simple graphs
└── Full-text search?
    └── Elasticsearch, PostgreSQL full-text search for basic needs

Consistency needs:
├── ACID required (banking, finance)           → SQL
├── Eventually consistent is acceptable         → Many NoSQL
├── Hybrid: SQL for transactional, NoSQL for views → CQRS pattern
└── When in doubt: start with PostgreSQL. It does 90% of everything well.
```

---

## DT-13: Pull vs Push Message Consumption

```
Consumer characteristics:
├── Consumer can keep up with producer rate?
│   ├── YES → Pull (consumer controls pace, simpler)
│   └── NO  → Push (producer controls delivery) OR Pull with batching
├── Consumer latency sensitivity?
│   ├── Near real-time required (< 100ms)         → Push (WebSocket, SSE, gRPC stream)
│   ├── Seconds of delay acceptable                → Pull (Kafka poll, AMQP)
│   └── Minutes of delay acceptable                → Pull with scheduled job
├── Consumer reliability?
│   ├── Consumer may be down frequently?            → Pull (broker stores messages, consumer catches up)
│   └── Consumer always available?                  → Push (simpler, lower latency)
└── Consumer processing time?
    ├── Uniform and fast (ms)                       → Push is fine
    └── Variable and potentially slow (seconds+)    → Pull (consumer controls commit after processing)

Broker perspective:
├── Need to preserve message order per entity?     → Pull with partition key (Kafka)
├── Need exactly-once semantics?                    → Pull with idempotent consumer + transactional outbox
└── Simple work queue (task distribution)?          → Push (RabbitMQ, SQS with long polling)
```

---

## DT-14: Authentication Strategy (JWT vs Opaque Token vs Session)

```
Client type:
├── SPA (browser-based)?
│   ├── Can you securely store a refresh token? (BFF pattern)
│   │   ├── YES → JWT (access token) + httpOnly cookie (refresh token)
│   │   └── NO  → BFF manages session, SPA uses session cookie
│   └── Need to call third-party APIs? → JWT (Bearer token)
├── Mobile app?
│   └── JWT with refresh token rotation (store in secure enclave)
├── Server-to-server?
│   └── JWT (client credentials grant) or API Key with HMAC signing
└── Traditional server-rendered app?
    └── Session cookie (simpler, more secure than client-side JWT)

Revocation needs:
├── Must be able to revoke immediately?             → Opaque token (introspection) or session
├── Short-lived tokens OK (5-15 min)?                → JWT with short expiry + refresh
└── No revocation needed (machine-to-machine)?       → JWT is perfect

Token contents:
├── Need to carry user attributes to avoid DB lookup? → JWT (but keep payload small)
├── Don't care about payload, just identity?          → Opaque token
└── Need permission claims in token?                  → JWT with scope/role claims
```

---

## DT-15: Event-Driven vs Request-Response

```
Communication pattern:
├── Does caller need an immediate response?
│   ├── YES → Request-Response (REST, gRPC)
│   └── NO  → Consider event-driven
├── Does the caller care about side effects?
│   ├── YES (need confirmation) → Request-Response OR request + async callback
│   └── NO (fire and forget)     → Event-driven
├── Are there multiple consumers for the same action?
│   ├── YES → Event-driven (publish once, many subscribers)
│   └── NO  → Either pattern works
└── Is temporal decoupling valuable?
    ├── YES (consumer may be down, should process when ready) → Event-driven
    └── NO (consumer always available, synchronous is simpler)  → Request-Response

When to prefer Event-Driven:
- Multiple services need to react to the same business event
- Need to maintain an audit log of everything that happened
- Service boundaries align with business capabilities, not technical layers
- Want to reduce coupling between services

When to prefer Request-Response:
- User is waiting for an answer (HTTP API)
- Need strong consistency guarantees (transaction spans data + response)
- Simple operations where async adds complexity without benefit
- Synchronous orchestration (Saga can use both: command = request, event = response)
```

---

## DT-16: Optimistic Lock vs Pessimistic Lock vs Distributed Lock

```
Is the conflict rate HIGH? (same resource contested frequently)
├── YES → Pessimistic lock
│   └── Hold for < 1 second ONLY. Release in finally block.
└── NO (conflicts are rare) → Optimistic lock

Is the resource in a single database?
├── YES → Optimistic lock (@Version) or SELECT ... FOR UPDATE
│   ├── Read-modify-write flow, conflicts rare → Optimistic lock
│   │   // @Version private Long version;
│   │   // UPDATE ... SET version = version + 1 WHERE id = ? AND version = ?
│   │   // If rows affected = 0 → retry or fail (someone else updated)
│   └── Must guarantee exclusive access right now → SELECT ... FOR UPDATE
│       // Holds row lock until transaction commits
└── NO (resource spans services/infrastructure) → Distributed lock
    ├── Redis SET NX EX (lightweight, eventual consistency OK)
    ├── ZooKeeper/etcd ephemeral nodes (strong consistency required)
    └── Database advisory lock (if shared DB exists)

Critical infrastructure considerations:
- Distributed locks MUST have automatic TTL expiry (AP-18)
- Optimistic lock retry count MUST be bounded (no infinite retries)
- Pessimistic lock timeout MUST be set (AP-21)
- NONE of these guarantee correctness for idempotent operations — use Idempotency Key
```

---

## DT-17: Composition vs Inheritance

```
Is the relationship truly "is-a" and stable?
├── YES → Does the base class exist purely to share implementation?
│   ├── YES → Prefer composition. Extract shared logic to a collaborator.
│   └── NO (true subtype polymorphism needed) → Inheritance is appropriate.
│       Examples: sealed interface implementations, framework extension points
└── NO (relationship is "has-a" or "uses-a") → ALWAYS composition.

Does the child need to reuse ONLY some behavior from parent?
├── YES → Composition. Inheriting for partial reuse creates fragile base class.
└── NO (child genuinely extends ALL parent behavior)

Are you trying to reuse cross-cutting concerns?
├── Auditing, logging, caching, validation?
│   └── Decorator pattern / AOP / Middleware. NOT inheritance.
└── Data + behavior together?
    └── If data only: Record / data class. If behavior: Composition.

Signal that inheritance is wrong:
- Base class has methods the child doesn't need (AP-24)
- Base class needs to know about child types (violates Open/Closed)
- You need multiple inheritance (diamond problem)
- Child overrides methods just to make them no-ops
```

---

## DT-18: API Pagination Strategy (Offset vs Cursor)

```
Dataset characteristics:
├── Small dataset (< 1000 rows), infrequent inserts?
│   └── Offset pagination is fine (page/size). Simple, universal.
├── Large dataset, frequent inserts/deletes?
│   └── Cursor-based pagination (WHERE id > :lastId).
│       Avoids row duplication/skipping when data changes between pages.
├── Need to jump to arbitrary page (page 50 of 5000)?
│   └── Offset. Cursor can't skip pages.
├── Need stable ordering under concurrent writes?
│   └── Cursor (based on immutable sequential ID). Offset shifts pages during writes.
└── Real-time feed (Twitter timeline, chat messages)?
    └── Cursor with reverse order. Newest first, "load more" = older cursor.

Performance:
├── Offset on large tables → DB must scan and skip OFFSET rows → O(n) cost
│   └── Acceptable for small offsets. At page 1000 of 100/page = scan 100,000 rows.
└── Cursor → O(1) index seek. Always fast regardless of position.

Hybrid approach: Use cursor for primary navigation, offset for jump-to-page admin tooling.
```

---

## DT-19: Method Extraction Decision

```
Is this code block > 20 lines?
├── YES → Does it have a single, coherent purpose?
│   ├── YES → Extract to a well-named private method.
│   └── NO  → Does it mix abstraction levels?
│       ├── YES → Extract each level into its own method.
│       └── NO  → Restructure, then extract.
└── NO  → Is this block reused elsewhere in the class?
    ├── YES → Extract to private method (DRY within class boundary).
    └── NO  → Is this block a comment-worthy logical section?
        ├── YES → Extract method. The method name IS the comment.
        └── NO  → Keep inline. Extraction would fragment readability.

Signal it's time to extract:
- You need a comment to explain what a block of code does
- You can describe the block with a single verb phrase (e.g., "validate cart")
- The block uses local variables that are not used elsewhere in the parent method
- Indentation is 3+ levels deep

Signal it's NOT time to extract:
- The block is 3-5 lines of straightforward code
- Extracting would require passing 5+ parameters
- The extracted method would only be called once AND the logic is obvious inline
```

---

## DT-20: When to Introduce a Module Boundary

```
Does this code represent a distinct business capability?
├── YES → Can it be deployed independently?
│   ├── YES → Separate service (microservice) or separate deployable module.
│   └── NO  → Separate package/module with explicit public API.
└── NO  → Is this code used by multiple other modules?
    ├── YES → Extract to shared library with versioned API.
    └── NO  → Keep in the same module. Don't create boundaries preemptively.

Is the team structure Conway's Law-aligned?
├── Different team owns this code? → Separate module with clear ownership.
└── Same team owns everything?     → Package separation is sufficient.

Do changes to this code require different review/deploy cadence?
├── YES → Separate module. Don't couple fast-changing and stable code.
└── NO  → Same module is fine.

Is the dependency direction clear and acyclic?
├── YES (depends on abstractions, not concretions) → Package-level separation OK.
├── NO (circular or unclear) → Refactor to remove cycle BEFORE creating module boundary.
└── When in doubt: modular monolith with ArchUnit/Modulith enforcing boundaries.
    Cheaper than microservices, same architectural benefits.
```

---

## How to Use Decision Trees

When making a design choice during code generation:

1. Identify the decision category (interface, data type, error handling, etc.)
2. Trace the tree top to bottom using the actual context
3. Apply the recommended approach
4. If the tree recommends against a pattern you were about to use, **reconsider** — the tree encodes expert heuristics that prevent common mistakes
