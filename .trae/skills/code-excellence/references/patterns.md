# Pattern Catalog

## Purpose

Named, reusable solution patterns with concrete multi-language implementations.
Each pattern includes: when to use it, when NOT to use it, and production-grade code.

---

## Pattern: Result Type Instead of Exceptions

**Use when**: An operation has multiple known outcomes (success, not-found, validation-failure, permission-denied). You want callers to handle every outcome explicitly.

**Do NOT use when**: The failure mode is truly exceptional and unrecoverable (e.g., OutOfMemoryError, disk failure in a critical path).

### Java 21
```java
sealed interface OrderResult {
    record Success(Order order) implements OrderResult {}
    record NotFound(Long orderId) implements OrderResult {}
    record PaymentRequired(Order order, Money remaining) implements OrderResult {}
    record InsufficientStock(String sku, int requested, int available) implements OrderResult {}
}

// Caller — compiler enforces exhaustive handling
String message = switch (result) {
    case OrderResult.Success(var order) ->
        "Order %d confirmed".formatted(order.id());
    case OrderResult.NotFound(var id) ->
        "Order %d not found".formatted(id);
    case OrderResult.PaymentRequired(var order, var remaining) ->
        "Order %d needs additional %s".formatted(order.id(), remaining);
    case OrderResult.InsufficientStock(var sku, var req, var avail) ->
        "SKU %s: requested %d, only %d available".formatted(sku, req, avail);
};
```

### Kotlin
```kotlin
sealed class OrderResult {
    data class Success(val order: Order) : OrderResult()
    data class NotFound(val orderId: Long) : OrderResult()
    data class PaymentRequired(val order: Order, val remaining: Money) : OrderResult()
    data class InsufficientStock(val sku: String, val requested: Int, val available: Int) : OrderResult()
}

val message = when (result) {
    is OrderResult.Success -> "Order ${result.order.id} confirmed"
    is OrderResult.NotFound -> "Order ${result.orderId} not found"
    is OrderResult.PaymentRequired -> "Order ${result.order.id} needs additional ${result.remaining}"
    is OrderResult.InsufficientStock -> "SKU ${result.sku}: requested ${result.requested}, only ${result.available} available"
}
```

### Go
```go
type OrderResult interface { isOrderResult() }

type OrderSuccess struct{ Order *Order }
func (OrderSuccess) isOrderResult() {}

type OrderNotFound struct{ OrderID int64 }
func (OrderNotFound) isOrderResult() {}

// Caller with type switch
switch r := result.(type) {
case OrderSuccess:
    fmt.Printf("Order %d confirmed\n", r.Order.ID)
case OrderNotFound:
    fmt.Printf("Order %d not found\n", r.OrderID)
default:
    panic("unhandled result type") // compiler won't catch missing cases
}
```

### Python 3.12+
```python
type OrderResult = Success | NotFound | PaymentRequired | InsufficientStock

@dataclass(frozen=True)
class Success: order: Order

@dataclass(frozen=True)
class NotFound: order_id: int

match result:
    case Success(order=order):
        msg = f"Order {order.id} confirmed"
    case NotFound(order_id=oid):
        msg = f"Order {oid} not found"
    case _:
        raise ValueError(f"Unhandled result: {result}")
```

---

## Pattern: Idempotency Key

**Use when**: An operation has side effects (payment, email, order creation) and may be retried due to network failures.

**Do NOT use when**: The operation is naturally idempotent (GET, reading a file, pure computation).

```java
// Controller
@PostMapping("/orders")
public ResponseEntity<?> create(
    @RequestHeader("Idempotency-Key") String key,
    @Valid @RequestBody CreateOrderRequest req
) {
    return idempotencyStore.execute(key, () -> {
        var order = orderService.create(req);
        return ResponseEntity.created(uri).body(OrderDto.from(order));
    });
}

// Idempotency store — race-condition safe
@Service
public class IdempotencyStore {
    private final ConcurrentMap<String, StoredResponse> cache = new ConcurrentHashMap<>();

    public <T> T execute(String key, Supplier<T> action) {
        var existing = cache.get(key);
        if (existing != null) return (T) existing.response();
        var result = action.get();
        cache.put(key, new StoredResponse(result, Instant.now().plus(Duration.ofHours(24))));
        return result;
    }
}
```

---

## Pattern: Feature Toggle

**Use when**: You need to deploy code that is not yet ready for all users, or need a kill switch for risky changes.

**Structure**:
```
Controller → ToggleRouter → [OldImplementation | NewImplementation]
```

```java
@Component
public class PaymentToggleRouter implements PaymentProcessor {
    private final PaymentProcessor legacy;
    private final PaymentProcessor v2;
    private final FeatureToggle toggle;

    public PaymentResponse process(PaymentRequest req) {
        return toggle.isEnabled("payment-v2", req.userId())
            ? v2.process(req)
            : legacy.process(req);
    }
}

// Test both paths independently
@Test void legacyPathIsUntouched() { ... }
@Test void v2PathDelegatesCorrectly() { ... }
```

---

## Pattern: Saga (Distributed Transaction)

**Use when**: A business operation spans multiple services and you cannot use 2PC/XA.

**Structure**: Each step has a corresponding compensating action.

```java
public sealed interface SagaStep<T> {
    record Success<T>(T result) implements SagaStep<T> {}
    record Failure(String step, String reason) implements SagaStep<T> {}
}

public OrderResult placeOrder(OrderRequest req) {
    var reservation = reserveInventory(req.items());
    if (reservation instanceof SagaStep.Failure f) return new InsufficientStock(f.reason());

    var payment = capturePayment(req.payment());
    if (payment instanceof SagaStep.Failure f) {
        // Compensate
        releaseInventory(reservation);
        return new PaymentRequired(f.reason());
    }

    var shipment = createShipment(req.address());
    if (shipment instanceof SagaStep.Failure f) {
        refundPayment(payment);        // compensate
        releaseInventory(reservation); // compensate
        return new ShipmentFailed(f.reason());
    }

    return new Success(new Order(reservation, payment, shipment));
}
```

---

## Pattern: Outbox (Reliable Event Publishing)

**Use when**: You must publish an event AND update the database atomically. You cannot afford lost events.

**Structure**: Write event to an outbox table in the same DB transaction. A separate process polls and publishes.

```java
@Transactional
public void approveOrder(Long orderId) {
    var order = orderRepo.findById(orderId).orElseThrow();
    order.approve();
    orderRepo.save(order); // UPDATE orders

    // Atomically store event in same transaction
    outboxRepo.save(new OutboxEvent(
        "OrderApproved",
        new OrderApprovedPayload(order.id(), order.total()).toJson(),
        Instant.now()
    ));
}

// Separate scheduled job or CDC connector publishes to Kafka
@Scheduled(fixedDelay = 1000)
public void publishOutboxEvents() {
    var events = outboxRepo.findUnpublished(100);
    for (var event : events) {
        kafka.send(event.type(), event.payload());
        event.markPublished();
    }
}
```

---

## Pattern: Cache-Aside

**Use when**: Read-heavy data that is expensive to compute/query and can tolerate slight staleness.

```java
public UserProfile getProfile(Long userId) {
    var cached = cache.get("user:" + userId);
    if (cached != null) return cached;

    var profile = db.query("SELECT ... WHERE user_id = ?", userId);
    if (profile != null) {
        cache.set("user:" + userId, profile, Duration.ofMinutes(5));
    }
    return profile;
}

public void updateProfile(Long userId, UserProfile profile) {
    db.update("UPDATE users SET ... WHERE user_id = ?", userId);
    cache.delete("user:" + userId); // invalidate, don't update
}
```

---

## Pattern: Circuit Breaker

**Use when**: Calling an external service that may be slow or unavailable. You want to fail fast rather than accumulate waiting threads.

```java
@Component
public class ResilientPaymentClient {
    private final CircuitBreaker breaker = CircuitBreaker.of("payment",
        CircuitBreakerConfig.custom()
            .failureRateThreshold(50)         // open when 50% fail
            .waitDurationInOpenState(Duration.ofSeconds(30))
            .slidingWindowSize(10)
            .build()
    );

    private final PaymentClient client;

    public PaymentResponse charge(PaymentRequest req) {
        return breaker.executeSupplier(() -> client.charge(req));
        // When open: throws CallNotPermittedException immediately
    }
}

// Controller handles open circuit gracefully
@ExceptionHandler(CallNotPermittedException.class)
public ResponseEntity<?> serviceUnavailable() {
    return ResponseEntity.status(503).body(Map.of("error", "PAYMENT_UNAVAILABLE"));
}
```

---

## Pattern: Strangler Fig (Legacy Migration)

**Use when**: Replacing a legacy system incrementally without a big-bang cutover.

```java
@Component
public class OrderServiceRouter implements OrderService {
    private final LegacyOrderService legacy;
    private final NewOrderService newService;
    private final ToggleService toggles;

    public OrderResult place(OrderRequest req) {
        // Route per feature, not per entire domain
        if (toggles.isEnabled("new-order-placement", req.tenantId())) {
            return newService.place(req);
        }
        return legacy.place(req);
    }
}
```

**Migration sequence**:
1. Build new service behind toggle (0% traffic)
2. Enable for 1% → 10% → 50% → 100%
3. Delete legacy code

---

## Pattern: CQRS (Command Query Responsibility Segregation)

**Use when**: Read and write models have fundamentally different shapes. Read side needs denormalized, optimized views; write side needs normalized, integrity-guaranteed models.

**Do NOT use when**: Simple CRUD where read and write models are identical. CQRS adds complexity that pays off only when the read/write gap is significant.

**Structure**:
```
Command (Write) Side:          Query (Read) Side:
POST /orders                   GET /orders/{id}
  → Command (validated)          → Query (projected view)
  → Aggregate (Domain Logic)     → Read Model (denormalized)
  → Event Store / DB             → Materialized View / Cache
  → Project Read Model
```

```java
// Write side — Command, Aggregate, Event
public record PlaceOrderCommand(Long userId, List<OrderItem> items) {}

@Service
public class OrderCommandHandler {
    private final EventStore eventStore;

    @Transactional
    public void handle(PlaceOrderCommand cmd) {
        var order = OrderAggregate.create(cmd);
        eventStore.save(order.getUncommittedEvents());
        // Read model will be updated asynchronously by event handler
    }
}

// Read side — Projection, Query, Read Model
public record OrderView(Long id, String status, String userName,
        int itemCount, Money total, Instant createdAt) {}

@Service
public class OrderQueryService {
    private final JdbcTemplate jdbc;

    public Optional<OrderView> findById(Long id) {
        return jdbc.queryForOptional("SELECT o.id, o.status, u.name as user_name, ...", ...);
    }

    public List<OrderView> findRecent(int limit) {
        return jdbc.query("SELECT ... FROM order_views ORDER BY created_at DESC LIMIT ?", limit);
    }
}

// Event handler keeps read model in sync
@Component
public class OrderViewProjector {
    @EventListener
    public void on(OrderCreatedEvent e) {
        jdbc.update("INSERT INTO order_views (id, status, ...) VALUES (?, ?, ...)", ...);
    }
}
```

---

## Pattern: Event Sourcing

**Use when**: You need a complete audit trail, temporal queries ("what was the state at time T?"), or your domain is inherently event-driven (banking, accounting, logistics).

**Do NOT use when**: Simple CRUD, no audit requirements, or event rebuild performance is unacceptable without snapshotting infrastructure.

**Structure**: Store events, not current state. Rebuild state by replaying events.

```java
// Event store
public interface EventStore {
    void append(Long aggregateId, List<DomainEvent> events, int expectedVersion);
    List<DomainEvent> load(Long aggregateId);
}

// Aggregate rebuilds from event stream
public class OrderAggregate {
    private Long id;
    private OrderStatus status;
    private Money total;
    private int version;

    public static OrderAggregate fromEvents(List<DomainEvent> events) {
        var order = new OrderAggregate();
        for (var event : events) {
            order.apply(event);
        }
        return order;
    }

    // Command → Event
    public List<DomainEvent> approve() {
        if (status != PENDING) throw new IllegalStateException("Only pending orders can be approved");
        return List.of(new OrderApproved(id, Instant.now()));
    }

    // Event → State
    private void apply(DomainEvent event) {
        switch (event) {
            case OrderCreated e -> { id = e.orderId(); status = PENDING; total = e.total(); }
            case OrderApproved e -> status = APPROVED;
            case OrderCancelled e -> status = CANCELLED;
        }
        version++;
    }
}

// Snapshot for rebuild performance
public record OrderSnapshot(Long aggregateId, int version, byte[] state) {}
```

**Replay strategy**: On load, start from latest snapshot + apply events after snapshot version. For large streams (>10k events), snapshot every N events.

---

## Pattern: Bulkhead (Resource Isolation)

**Use when**: You have multiple external dependencies and want to prevent one slow dependency from exhausting all resources (threads, connections).

**Do NOT use when**: All dependencies are equally critical and share a single thread pool by design.

```java
@Component
public class BulkheadedPaymentClient {
    // Separate thread pools per dependency
    private final ExecutorService paymentPool = Executors.newFixedThreadPool(5);
    private final ExecutorService notificationPool = Executors.newFixedThreadPool(3);

    public CompletableFuture<PaymentResult> charge(PaymentRequest req) {
        return CompletableFuture.supplyAsync(() -> paymentGateway.charge(req), paymentPool);
    }

    public CompletableFuture<Void> notify(Notification n) {
        return CompletableFuture.runAsync(() -> notifier.send(n), notificationPool);
    }
    // If payment gateway slows down, only 5 threads are blocked.
    // Notifications continue unimpeded on their own 3 threads.
}
```

```yaml
# Resilience4j bulkhead config
resilience4j:
  bulkhead:
    instances:
      paymentService:
        max-concurrent-calls: 5
        max-wait-duration: 100ms
      notificationService:
        max-concurrent-calls: 3
        max-wait-duration: 500ms
```

---

## Pattern: Retry with Exponential Backoff + Jitter

**Use when**: Calling external services that may experience transient failures (network blip, temporary overload).

**Do NOT use when**: The failure is deterministic (validation error, not-found) — retrying won't help.

```java
public class ExponentialBackoffRetry {
    private static final int MAX_RETRIES = 3;
    private static final Duration BASE_DELAY = Duration.ofMillis(100);
    private static final Duration MAX_DELAY = Duration.ofSeconds(5);
    private final Random random = new Random();

    public <T> T execute(Supplier<T> action) {
        for (int attempt = 0; attempt <= MAX_RETRIES; attempt++) {
            try {
                return action.get();
            } catch (TransientException e) {
                if (attempt == MAX_RETRIES) throw new MaxRetriesExceededException(e);
                sleep(backoffWithJitter(attempt));
            }
        }
        throw new IllegalStateException("unreachable");
    }

    private Duration backoffWithJitter(int attempt) {
        // Exponential: BASE * 2^attempt, capped at MAX
        var exponential = BASE_DELAY.multipliedBy((long) Math.pow(2, attempt));
        var capped = exponential.compareTo(MAX_DELAY) > 0 ? MAX_DELAY : exponential;
        // Jitter: random 0-50% of capped delay
        var jitter = (long) (capped.toMillis() * random.nextDouble() * 0.5);
        return capped.plusMillis(jitter);
    }
    // Without jitter: all retries hit at the same instant → thundering herd
    // With jitter: retries spread out across the backoff window
}
```

---

## Pattern: Dead Letter Queue (DLQ)

**Use when**: Processing messages/events where poison messages (unprocessable, malformed) would block the entire queue.

**Do NOT use when**: Messages are ephemeral (logs, metrics) where loss is acceptable.

```java
// Main handler — moves poison to DLQ, continues processing
@Component
public class OrderEventHandler {
    private final OrderProcessor processor;
    private final DeadLetterQueue dlq;

    @KafkaListener(topics = "orders")
    public void handle(OrderEvent event) {
        try {
            processor.process(event);
        } catch (NonRetryableException e) {
            // Poison message — move to DLQ, do NOT block the queue
            dlq.send("orders.dlq", event,
                DeadLetterMetadata.of(e.getClass().getSimpleName(), e.getMessage(), Instant.now()));
            log.warn("Moved unprocessable event {} to DLQ: {}", event.orderId(), e.getMessage());
            // Do NOT rethrow — let the consumer continue to next message
        }
    }
}

// DLQ inspection and replay endpoint
@PostMapping("/admin/dlq/orders/replay/{messageId}")
public void replay(@PathVariable String messageId) {
    var event = dlq.get("orders.dlq", messageId);
    processor.process(event); // after manual fix
    dlq.ack("orders.dlq", messageId);
}
```

---

## Pattern: Rate Limiting (Token Bucket)

**Use when**: Protecting your API or an external API from overload. Enforcing per-user or per-IP quotas.

**Do NOT use when**: Traffic is predictably low or you have upstream rate limiting already.

```java
public class TokenBucketRateLimiter {
    private final long capacity;         // max tokens
    private final double refillRate;     // tokens per second
    private double tokens;
    private long lastRefill;

    public TokenBucketRateLimiter(long capacity, double refillRate) {
        this.capacity = capacity;
        this.refillRate = refillRate;
        this.tokens = capacity;
        this.lastRefill = System.nanoTime();
    }

    public synchronized boolean tryConsume() {
        refill();
        if (tokens >= 1) {
            tokens -= 1;
            return true;
        }
        return false; // rate limited
    }

    private void refill() {
        long now = System.nanoTime();
        double elapsed = (now - lastRefill) / 1_000_000_000.0;
        tokens = Math.min(capacity, tokens + elapsed * refillRate);
        lastRefill = now;
    }
}

// Usage
@Component
public class RateLimitedController {
    private final TokenBucketRateLimiter limiter =
        new TokenBucketRateLimiter(100, 10); // 100 burst, 10/sec sustained

    @PostMapping("/api/orders")
    public ResponseEntity<?> create(@RequestBody OrderRequest req) {
        if (!limiter.tryConsume()) {
            return ResponseEntity.status(429)
                .header("Retry-After", "1")
                .body(Map.of("error", "RATE_LIMITED"));
        }
        return orderService.create(req);
    }
}
```

---

## Pattern: Specification (Criteria Query)

**Use when**: You need to combine query filters dynamically at runtime. Domain experts define business rules as composable specifications.

**Do NOT use when**: Query filters are fixed at compile time — simple repository methods suffice.

```java
public interface Specification<T> {
    boolean isSatisfiedBy(T candidate);
    Specification<T> and(Specification<T> other);
    Specification<T> or(Specification<T> other);
    Specification<T> not();
}

// Composable business rules
public class OrderSpecifications {
    public static Specification<Order> isPending() {
        return o -> o.status() == PENDING;
    }

    public static Specification<Order> totalAbove(Money threshold) {
        return o -> o.total().compareTo(threshold) > 0;
    }

    public static Specification<Order> placedBy(User user) {
        return o -> o.userId().equals(user.id());
    }
}

// Compose at runtime
var highValuePending = isPending()
    .and(totalAbove(new Money("1000", "CNY")));

var alerts = orders.stream()
    .filter(highValuePending::isSatisfiedBy)
    .toList();

// JPA integration
@Repository
public interface OrderRepository extends JpaRepository<Order, Long>,
        JpaSpecificationExecutor<Order> {
    // Spring Data JPA natively supports Specification composition
}

var spec = Specification
    .where(OrderSpecs.hasStatus(PENDING))
    .and(OrderSpecs.totalGreaterThan(new Money("1000", "CNY")));
var results = orderRepo.findAll(spec, pageable);
```

---

## Quick Reference: Which Pattern When

| Signal | Pattern |
|--------|---------|
| Method can return multiple distinct outcomes | **Result Type** |
| External call can be retried, has side effects | **Idempotency Key** |
| Code needs to deploy but not activate yet | **Feature Toggle** |
| Operation spans 2+ services, no 2PC | **Saga** |
| Must update DB + publish event atomically | **Outbox** |
| Data is read-heavy, expensive, staleness OK | **Cache-Aside** |
| External dependency is unreliable | **Circuit Breaker** |
| Incrementally replacing a legacy system | **Strangler Fig** |
| Read and write models are fundamentally different | **CQRS** |
| Need complete audit trail + temporal queries | **Event Sourcing** |
| One slow dependency starving others of threads | **Bulkhead** |
| Transient failures on external calls | **Retry + Backoff + Jitter** |
| Poison messages blocking queue processing | **Dead Letter Queue** |
| API protection against overload / abuse | **Rate Limiting (Token Bucket)** |
| Dynamic query filters composed at runtime | **Specification** |
