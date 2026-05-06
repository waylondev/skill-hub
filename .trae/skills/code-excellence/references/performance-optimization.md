# Performance Optimization Patterns — Architect-Level Reference

## Purpose

This reference encodes four performance-critical patterns that every architect must
master to build systems that scale. Each pattern follows the **Use when → ❌ Wrong →
✅ Expert Fix → Expert Note** format. Default language is Java. Every decision has
a measurable impact on throughput, latency, and resource cost.

---

## PF-1: Caching Strategy Tiers (L1 / L2 / L3)

**Use when**: You need to reduce database load for read-heavy workloads. Any query
executed > 10 times/second with stable results is a caching candidate.

### Tier Architecture

| Tier | Technology | Latency | Capacity | TTL Range | Failure Mode |
|------|-----------|---------|----------|-----------|-------------|
| **L1** | Caffeine (in-process) | ~1μs | MB-GB (heap-bound) | Seconds-Minutes | JVM restart = total loss |
| **L2** | Redis (distributed) | ~1ms | GB-TB (memory-bound) | Minutes-Hours | Network partition = miss |
| **L3** | Database (PostgreSQL) | ~5ms | TB+ (disk-bound) | Permanent | Single point of truth |

### ❌ Wrong — Single-Layer Cache, No Jitter, Naive Miss Handling

```java
// Disaster 1: Only Redis, no L1 — every read pays 1ms network round-trip
public Product getProduct(String id) {
    var cached = redis.get("product:" + id);
    if (cached != null) return cached;
    var product = db.findById(id).orElseThrow();
    redis.set("product:" + id, product, Duration.ofHours(1)); // 100k keys expire simultaneously
    return product;
}

// Disaster 2: Cache-Aside with race condition
public Product getProductRace(String id) {
    var cached = redis.get("product:" + id);
    if (cached != null) return cached;
    // 1000 concurrent threads all reach here → 1000 DB queries for the same key
    var product = db.findById(id).orElseThrow();
    redis.set("product:" + id, product, Duration.ofMinutes(10));
    return product;
}
```

### Root Cause

A single Redis layer wastes ~1ms per read that could be served at ~1μs from Caffeine.
Uniform TTL creates an expiry cliff — all keys expire within the same second window
→ DB receives a synchronized spike of 100,000 queries → "Cache Avalanche."
No mutex on cache miss means every concurrent request independently queries the DB
→ "Thundering Herd."

### ✅ Expert Fix — Three-Tier with Jitter + Hot-Key Mutex

```java
@Component
public class TieredCacheManager {
    private final Cache<String, Product> l1Cache;  // Caffeine
    private final RedisTemplate<String, Product> redis;
    private final ProductRepository db;
    private final Random random = ThreadLocalRandom.current();

    private static final Duration L1_TTL = Duration.ofMinutes(1);
    private static final Duration L2_TTL_BASE = Duration.ofMinutes(10);
    private static final int MAX_JITTER_SECONDS = 120;

    public TieredCacheManager(ProductRepository db, RedisTemplate<String, Product> redis) {
        this.db = db;
        this.redis = redis;
        this.l1Cache = Caffeine.newBuilder()
            .maximumSize(10_000)
            .expireAfterWrite(L1_TTL)
            .recordStats()
            .build();
    }

    public Product get(String id) {
        // L1: Caffeine — μs latency
        var product = l1Cache.getIfPresent(id);
        if (product != null) return product;

        // L2: Redis — ms latency, distributed
        product = redis.opsForValue().get("product:" + id);
        if (product != null) {
            l1Cache.put(id, product); // backfill L1
            return product;
        }

        // L3 miss → single-thread rebuild with distributed lock
        return rebuildWithLock(id);
    }

    private Product rebuildWithLock(String id) {
        var lockKey = "lock:rebuild:product:" + id;
        var lockValue = UUID.randomUUID().toString();

        // SET NX PX — atomic acquire with auto-expiry
        var acquired = redis.opsForValue()
            .setIfAbsent(lockKey, lockValue, Duration.ofSeconds(5));

        if (Boolean.TRUE.equals(acquired)) {
            try {
                var product = db.findById(id).orElseThrow();
                // Write L2 + L1 with jittered TTL
                var jitteredTtl = L2_TTL_BASE.plusSeconds(random.nextInt(MAX_JITTER_SECONDS));
                redis.opsForValue().set("product:" + id, product, jitteredTtl);
                l1Cache.put(id, product);
                return product;
            } finally {
                // Release only if we still own it (prevent accidental release after expiry)
                var current = redis.opsForValue().get(lockKey);
                if (lockValue.equals(current)) {
                    redis.delete(lockKey);
                }
            }
        }

        // Other threads: brief backoff then retry L1 → L2
        try { Thread.sleep(50); } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
        var retry = redis.opsForValue().get("product:" + id);
        if (retry != null) {
            l1Cache.put(id, retry);
            return retry;
        }
        // Absolute last resort — returning stale is better than crashing
        return l1Cache.getIfPresent(id);
    }
}
```

### Cache Consistency Strategy Selection

| Strategy | Read Path | Write Path | Consistency | Use When |
|----------|-----------|------------|-------------|----------|
| **Cache-Aside** | App reads cache → miss → DB → populate cache | App writes DB → invalidates cache | Eventual (gap window exists) | Read-heavy, stale tolerable (product catalog) |
| **Read-Through** | Cache layer loads from DB on miss transparently | Same as Cache-Aside | Eventual | Want clean separation, cache-aware DAO |
| **Write-Behind** | Same as Cache-Aside | App writes cache → cache async-flushes to DB | Eventual (risk of data loss on crash) | Write-heavy, durability not critical (analytics counters) |

```java
// Cache-Aside: explicit invalidation on write
@Transactional
public Product update(ProductUpdateRequest req) {
    var product = db.findById(req.id()).orElseThrow();
    product.apply(req);
    db.save(product);
    // Invalidate, not update. Next read will populate the correct value.
    redis.delete("product:" + req.id());
    l1Cache.invalidate(req.id());       // Caffeine supports explicit invalidation
    return product;
}

// Write-Behind: write to cache first, async persist to DB
public void incrementViewCount(String productId) {
    var key = "views:" + productId;
    redis.opsForValue().increment(key); // immediate, sub-ms
    // A scheduled flush job periodically writes batch increments to DB:
    // UPDATE products SET view_count = view_count + coalesce(cache_delta, 0)
    // Risk: Redis crash between increment and flush loses delta. Acceptable for views.
}
```

**Expert note**: Never use Write-Behind for financial or transactional data. The
window between cache write and DB flush is a durability hole. For inventory counts,
payment records, or anything audit-required, use Cache-Aside or Read-Through with
DB as the single source of truth. The performance gains of Write-Behind are real
but the operational risk is unbounded.

---

## PF-2: Batch vs Stream Processing

**Use when**: You need to process a large dataset (100K+ records) and must choose
between loading everything into memory vs processing incrementally. This decision
determines whether your service survives under production load or OOMs at 3 AM.

### ❌ Wrong — Loading Everything Into Memory

```java
// Disaster 1: SELECT * without pagination — OOM guaranteed above ~500K rows
public void processAllOrders() {
    var orders = orderRepo.findAll();          // 2 million rows → heap explodes
    orders.forEach(this::processOrder);        // GC death spiral before first record is processed
}

// Disaster 2: Unbounded parallel stream — thread pool exhaustion
public void processOrdersParallel() {
    orderRepo.findAll().parallelStream()       // ForkJoinPool.commonPool() — 100% CPU, all cores
        .forEach(this::processOrder);          // Thread contention + DB connection pool exhaustion
}

// Disaster 3: File processing in one shot
public byte[] downloadReport() {
    var data = s3Client.getObject(bucket, "report-2025.csv").readAllBytes(); // 5 GB file → OOM
    return transform(data);                    // Never reaches this line
}
```

### Root Cause

Loading an entire dataset into a single collection assumes infinite memory. The JVM
heap is finite. A 2-million-row `SELECT *` allocates hundreds of MB for the ResultSet,
each entity, and its Hibernate proxy graph. GC pauses spike to seconds. The OS OOM
killer terminates the process. This is the #1 cause of "works in dev, dies in prod."

### ✅ Expert Fix — Controlled Batch with Chunked Processing

```java
@Component
public class BatchOrderProcessor {
    private static final int CHUNK_SIZE = 500;        // Tuned to p95 response time < 1s
    private static final int FLUSH_INTERVAL = 100;    // Clear EntityManager every N chunks

    private final OrderRepository orderRepo;
    private final EntityManager entityManager;

    public BatchResult processAll(OrderProcessContext ctx) {
        var pageable = PageRequest.of(0, CHUNK_SIZE, Sort.by("id"));
        var totalProcessed = 0;
        var totalFailed = 0;

        Page<Order> page;
        do {
            page = orderRepo.findByStatus(ctx.status(), pageable);
            for (var order : page.getContent()) {
                try {
                    processOrder(order);
                    totalProcessed++;
                } catch (Exception e) {
                    metrics.orderProcessFailure.increment();
                    log.error("Failed to process order {}", order.id(), e);
                    ctx.deadLetterQueue().add(order.id(), e); // don't lose the record
                    totalFailed++;
                }
            }

            // CRITICAL: Clear persistence context after each chunk
            // Without this, Hibernate keeps all 500 entities in 1st-level cache → memory leak
            if (pageable.getPageNumber() % FLUSH_INTERVAL == 0) {
                entityManager.flush();
                entityManager.clear();
            }

            pageable = pageable.next();
        } while (page.hasNext());

        return new BatchResult(totalProcessed, totalFailed, ctx.deadLetterQueue().size());
    }
}
```

### Reactive Stream — When Data Never Ends

```java
// For infinite streams (Kafka, WebSocket, sensor data) — Reactive is the right tool
@Component
public class ReactiveOrderStreamProcessor {
    private final ReactiveOrderRepository repo;
    private final Sinks.Many<Order> hotStream;

    public ReactiveOrderStreamProcessor(ReactiveOrderRepository repo) {
        this.repo = repo;
        this.hotStream = Sinks.many().multicast().onBackpressureBuffer(1000);
    }

    public Flux<OrderResult> processStream() {
        return hotStream.asFlux()
            .onBackpressureBuffer(500)          // Buffer up to 500 before signaling upstream to slow down
            .flatMap(order -> processReactive(order)
                .timeout(Duration.ofSeconds(10)) // Kill zombies — no single order blocks the stream
                .onErrorResume(e -> {
                    metrics.reactiveOrderFailure.increment();
                    return Mono.empty();         // Skip failed, keep stream alive
                }),
                4  // concurrency — process 4 orders in parallel per subscriber
            )
            .doOnDiscard(Order.class, o ->
                log.warn("Backpressure discard: order {}", o.id()));
    }

    private Mono<OrderResult> processReactive(Order order) {
        return Mono.fromCallable(() -> doWork(order))
            .subscribeOn(Schedulers.boundedElastic()); // non-blocking processing
    }
}
```

### Decision Matrix: Batch vs Stream

| Signal | Batch (Chunked) | Reactive Stream |
|--------|----------------|-----------------|
| Data size | Finite, known boundary | Infinite or unknown (event streams) |
| Memory | Controlled — CHUNK_SIZE * entity size | Controlled — backpressure buffer size |
| Latency | Minutes to hours (scheduled batch) | Near real-time (sub-second) |
| Failure handling | Dead letter queue, retry batch | Circuit breaker, retry per item, skip |
| Complexity | Low — standard JDBC/JPA | High — reactive stack, debugging is harder |
| Operational | Cron job or Spring Batch | Persistent consumer (Kafka listener, WebFlux) |
| Typical use case | Monthly billing, report generation, ETL | Live order feed, IoT sensor ingestion, WebSocket push |

**Expert note**: The most dangerous choice is "batch with unbounded memory." If you
write a loop that accumulates results into an `ArrayList` without an upper bound,
you have chosen batch semantics with stream-like unbounded behavior — the worst of
both worlds. Always enforce a hard limit: either `CHUNK_SIZE` in batch mode or
`onBackpressureBuffer(N)` in reactive mode. The limit number doesn't need to be
perfect; any reasonable number is infinitely better than "no limit."

---

## PF-3: Async Non-blocking Patterns

**Use when**: You need to handle concurrent I/O-bound operations and thread-per-request
no longer scales (e.g., 1000+ concurrent connections on a 200-thread pool).

### ❌ Wrong — Three Common Async Mistakes

```java
// Mistake 1: Blocking call inside CompletableFuture pipeline
public CompletableFuture<OrderSummary> getSummary(Long id) {
    return CompletableFuture.supplyAsync(() -> {
        var order = orderRepo.findById(id).orElseThrow(); // BLOCKING on DB thread pool
        var payment = paymentRepo.findByOrderId(id);       // BLOCKING — thread wasted waiting
        return new OrderSummary(order, payment);
    });
    // supplyAsync uses ForkJoinPool.commonPool() by default.
    // Each blocking call occupies a thread. When all threads block, the pool is dead.
}

// Mistake 2: Reactive chain with blocking operation
public Mono<Order> getOrderReactive(String id) {
    return Mono.just(id)
        .map(orderRepo::findById)  // findById is BLOCKING JPA — subscribes on event loop thread
        .map(Optional::orElseThrow);
    // Netty event loop thread is now blocked for 50ms. All other requests queued behind it starve.
}

// Mistake 3: Nested futures without composition
public OrderDashboard buildDashboard(Long userId) {
    CompletableFuture<User> userFuture = userService.getAsync(userId);
    CompletableFuture<List<Order>> ordersFuture = orderService.getAsync(userId);
    CompletableFuture<Metrics> metricsFuture = metricsService.getAsync(userId);

    // Thread.sleep-style waiting — defeats the purpose of async
    userFuture.join();    // blocks current thread
    ordersFuture.join();  // blocks current thread
    metricsFuture.join(); // blocks current thread
    return new OrderDashboard(userFuture.join(), ordersFuture.join(), metricsFuture.join());
    // Total latency = t1 + t2 + t3 (sequential), not max(t1, t2, t3) (parallel)
}
```

### ✅ Expert Fix — Proper Composition with CompletableFuture + Virtual Threads

```java
// Fix 1: CompletableFuture composition — truly parallel
@Component
public class DashboardService {
    private final UserService userService;
    private final OrderService orderService;
    private final MetricsService metricsService;
    private final Executor dbExecutor; // dedicated pool for blocking DB calls

    public OrderDashboard buildDashboard(Long userId) {
        // All three fire simultaneously on the correct executor
        var userFuture = CompletableFuture.supplyAsync(
            () -> userService.get(userId), dbExecutor);
        var ordersFuture = CompletableFuture.supplyAsync(
            () -> orderService.getRecent(userId, 5), dbExecutor);
        var metricsFuture = CompletableFuture.supplyAsync(
            () -> metricsService.getDashboardMetrics(userId), dbExecutor);

        // thenCombine / allOf — no blocking, true composition
        return userFuture
            .thenCombine(ordersFuture, OrderDashboard::partial)
            .thenCombine(metricsFuture, (dash, metrics) -> dash.withMetrics(metrics))
            .orTimeout(3, TimeUnit.SECONDS)               // timeout → fallback, not hang
            .exceptionally(ex -> OrderDashboard.fromFallback(userId, ex.getMessage()))
            .join();  // Only join at the outermost boundary (controller return)
    }
}
```

```java
// Fix 2: Virtual Threads (Java 21+) — write sync code, execute async
// NO framework change required. Platform threads vs Virtual threads: same API.
@GetMapping("/orders/{id}")
public OrderDto getOrder(@PathVariable Long id) throws Exception {
    // Virtual threads are mounted on carrier threads. When a virtual thread
    // encounters a blocking I/O call, the carrier thread picks up another virtual thread.
    // Thread pool size becomes irrelevant — millions of virtual threads are feasible.
    try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
        var orderTask = scope.fork(() -> orderService.get(id));       // blocking on virtual thread
        var recsTask = scope.fork(() -> recommendationService.get(id)); // blocking on virtual thread
        var reviewTask = scope.fork(() -> reviewService.get(id));     // blocking on virtual thread

        scope.join();           // Wait for all or first failure
        scope.throwIfFailed();  // Propagate if any task failed

        return new OrderDto(orderTask.get(), recsTask.get(), reviewTask.get());
    }
    // Total wall-clock time = max(order, recs, review), not sum.
    // Code reads like synchronous, executes like parallel. No callback hell.
}
```

### Trade-off Analysis Table

| Dimension | CompletableFuture | Virtual Threads (Java 21+) | Reactive Streams (WebFlux) |
|-----------|------------------|---------------------------|--------------------------|
| **Throughput** | Medium-High (pool-bounded) | High (OS-thread-bounded) | Very High (event-loop-bounded) |
| **Latency at p99.9** | Good (dedicated pools) | Good (no context switching) | Excellent (no thread at all per request) |
| **Code readability** | Medium (callback nesting) | Excellent (sequential style) | Low (declarative, chaining) |
| **Debugging difficulty** | Medium (stack traces intact) | Easy (stack traces intact) | Hard (reactive stack trace is unreadable) |
| **Learning curve** | Medium | Low (write normal code) | Very High (rethink everything) |
| **Library ecosystem** | Most libs work (they're blocking) | All libs work (they're blocking) | Requires reactive drivers (R2DBC, WebClient) |
| **Memory per request** | ~1 MB per platform thread | ~2 KB per virtual thread | ~KB in event loop |
| **Best use case** | Moderate parallelism with existing blocking libs | High concurrency with blocking libs, migrate incrementally | Extreme scale (10K+ req/s), event streaming |
| **Worst use case** | Simple CRUD (over-engineering) | CPU-bound computation (no benefit) | Small team, tight deadline (complexity kills velocity) |

**Expert note**: The pragmatic path for 2025+ Java projects is **CompletableFuture for
bounded parallelism → migrate to Virtual Threads as you adopt Java 21.** Virtual threads
let you keep blocking JDBC/JPA/Hibernate without rewriting to R2DBC — the JVM handles
the non-blocking scheduling automatically. Reserve Reactive Streams for systems that are
already event-driven (Kafka Streams, WebSocket broadcasting) or where you have proven
that Virtual Threads don't meet the latency SLO. Do NOT adopt WebFlux for a CRUD app
just because it's "modern" — you will pay the complexity tax every single day.

---

## PF-4: Serialization Selection

**Use when**: You need to choose a data format for APIs, inter-service communication,
message queues, or persistent storage. The wrong choice silently increases latency by
10x and bandwidth cost by 5x at scale.

### ❌ Wrong — JSON for Everything, No Schema Evolution Plan

```java
// Disaster 1: JSON for high-throughput inter-service communication
@PostMapping("/orders")
public Order create(@RequestBody OrderRequest req) {
    // JSON payload: 2.3 KB per order. 100K orders/s = 230 MB/s serialization bandwidth
    return orderService.create(req);
}

// Disaster 2: JSON with BigInteger — silent precision loss
public record InventorySnapshot(String sku, long quantity, BigDecimal unitCost) {}
// Jackson serializes BigDecimal as double by default → 9.99 becomes 9.9900000000000002
// Frontend calculates wrong totals. Found 3 months later in financial audit.

// Disaster 3: No schema versioning — consumer breaks silently
// Producer adds field "taxAmount" to OrderEvent JSON.
// Consumer's deserialization ignores it (Jackson UnknownPropertyException if strict).
// Tax is calculated as 0 on the consumer side. Wrong report, wrong invoice, wrong P&L.
```

### Root Cause

JSON is human-readable but computationally expensive. Parsing 10 million JSON strings/day
consumes 40% of CPU. Its text-based nature inflates payload size 3-5x compared to binary
formats. Schema evolution is convention-based (ad-hoc), not enforced — producers and
consumers drift apart silently. The cost is invisible in dev (100 records) and catastrophic
in production (100M records).

### ✅ Expert Fix — Multi-Format Strategy with Schema Registry

### Comparative Benchmark Table

| Format | Throughput (msg/s) | Wire Size (vs JSON) | Latency p99 (ms) | Schema Evolution | Human Readable | Ecosystem |
|--------|-------------------|---------------------|------------------|-----------------|----------------|-----------|
| **JSON** | 50K | 1.0x (baseline) | 2.5 | Manual (convention) | Yes | Universal |
| **Protobuf** | 250K | 0.2x–0.3x | 0.4 | Contract-first (`.proto`), backward/forward compatible | No (binary) | gRPC, Kafka, Android |
| **Avro** | 200K | 0.2x–0.35x | 0.5 | Schema Registry enforced, reader/writer schema resolution | No (binary) | Kafka (Confluent), Hadoop |
| **MessagePack** | 120K | 0.5x–0.7x | 0.8 | Manual (same as JSON) | No (binary) | Language-native libraries |

```java
// Strategy 1: Protobuf for internal service-to-service (gRPC)
// order.proto
syntax = "proto3";
package com.example.orders;

message OrderCreatedEvent {
  string order_id = 1;
  string customer_id = 2;
  double amount = 3;              // Use decimal string for money in production
  string currency = 4;
  OrderStatus status = 5;

  enum OrderStatus {
    UNKNOWN = 0;                  // Always have 0 as UNKNOWN/default
    PENDING = 1;
    CONFIRMED = 2;
    CANCELLED = 3;
  }
}

// Java: Generated code with zero-reflection serialization
// 250K msgs/s on a single core vs 50K for Jackson
var event = OrderCreatedEvent.newBuilder()
    .setOrderId("ORD-12345")
    .setCustomerId("CUST-678")
    .setAmount(99.99)
    .setCurrency("USD")
    .setStatus(OrderCreatedEvent.OrderStatus.CONFIRMED)
    .build();

byte[] wire = event.toByteArray();  // ~40 bytes vs ~280 bytes JSON
```

```java
// Strategy 2: Avro for Kafka event streams with schema registry
@Configuration
public class KafkaAvroConfig {
    @Bean
    public KafkaTemplate<String, OrderCreatedEvent> avroTemplate(
            ProducerFactory<String, OrderCreatedEvent> factory) {
        var template = new KafkaTemplate<>(factory);
        template.setProducerListener(new LoggingProducerListener());
        return template;
    }
}

// Producer — schema auto-registered on first send (dev); CI/CD-managed in production
public void publishOrderCreated(Order order) {
    var event = OrderCreatedEvent.newBuilder()
        .setOrderId(order.id().toString())
        .setAmount(order.total().doubleValue())
        .setCurrency(order.currency())
        .setCustomerId(order.customerId().toString())
        .setCreatedAt(order.createdAt().toEpochMilli())
        .build();

    kafkaTemplate.send("order-events", order.id().toString(), event);
    // Confluent Schema Registry validates backward compatibility before accepting.
    // If this breaks compatibility → deployment is blocked BEFORE affecting production.
}
```

```java
// Strategy 3: JSON for external APIs — with proper configuration
@Configuration
public class JacksonConfig {
    @Bean
    public ObjectMapper objectMapper() {
        return new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .registerModule(new Jdk8Module())
            .registerModule(new MoneyModule())         // Serialize Money correctly
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
            .enable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES) // Fail fast on drift
            .setSerializationInclusion(JsonInclude.Include.NON_NULL)   // Reduce payload
            .configure(StreamWriteFeature.WRITE_BIGDECIMAL_AS_PLAIN, true); // Exact precision
    }
}

// DTO with explicit JSON contract — decoupled from internal model
public record OrderResponse(
    @JsonProperty("order_id") String orderId,
    @JsonProperty("status") String status,
    @JsonProperty("total") @JsonSerialize(using = MoneySerializer.class) Money total,
    @JsonProperty("items") List<OrderItemResponse> items,
    @JsonProperty("created_at") @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss'Z'") Instant createdAt
) {}
```

### Decision Tree

```
Start: Is this an internal service-to-service call?
  ├── YES → Is bandwidth the bottleneck?
  │         ├── YES → Protobuf (gRPC) — 5x smaller wire, 5x faster parse
  │         └── NO  → JSON is fine for low-volume internal APIs (< 1000 req/s)
  ├── NO → Is this a Kafka event stream with multiple consumers?
  │         ├── YES → Is schema evolution critical?
  │         │         ├── YES → Avro + Schema Registry (contract enforcement)
  │         │         └── NO  → Protobuf is also valid
  │         └── NO → Is this a public-facing REST API?
  │                   ├── YES → JSON + OpenAPI spec — universal compatibility
  │                   └── NO  → Is latency < 1ms required?
  │                              ├── YES → MessagePack (binary JSON, fast decode)
  │                              └── NO  → JSON with compression (gzip/Brotli)
  └── End
```

**Expert note**: The most expensive mistake is assuming "JSON for everything" is
cost-free. At 10M requests/day, the serialization CPU cost of JSON vs Protobuf is
approximately $500/month vs $100/month in compute (AWS us-east-1, c6g.large). But
the bigger cost is schema drift: Protobuf/Avro reject incompatible changes at build
time or deploy time. JSON lets them through and you discover them via a production
incident. That incident costs far more than the serialization CPU difference. Choose
JSON for external APIs (platform compatibility), Protobuf for internal RPC (performance),
Avro for Kafka (schema evolution governance).

---

## Quick Performance Checklist

When reviewing code for performance:

- [ ] Any read query executed > 10x/second without caching? → **Missing Cache Tier (PF-1)**
- [ ] Any cache with fixed, non-jittered TTL? → **Cache Avalanche Risk (PF-1)**
- [ ] Any cache miss path without mutex/single-flight? → **Thundering Herd (PF-1)**
- [ ] Any `findAll()` without pagination? → **OOM Risk (PF-2)**
- [ ] Any loop body accumulating results into unbounded List? → **Memory Leak (PF-2)**
- [ ] Any blocking call inside `CompletableFuture.supplyAsync` on common pool? → **Thread Starvation (PF-3)**
- [ ] Any blocking JPA call inside a reactive pipeline? → **Event Loop Blocking (PF-3)**
- [ ] Any `.join()` called on futures sequentially instead of `thenCombine`? → **False Async (PF-3)**
- [ ] Any high-throughput internal API using JSON? → **Serialize Waste (PF-4)**
- [ ] Any BigDecimal serialized without `WRITE_BIGDECIMAL_AS_PLAIN`? → **Silent Precision Loss (PF-4)**
- [ ] Any Kafka topic without Schema Registry enforced compatibility? → **Schema Drift (PF-4)**
