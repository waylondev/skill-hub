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
