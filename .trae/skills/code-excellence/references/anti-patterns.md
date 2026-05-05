# Anti-Pattern Library

## Purpose

Concrete examples of WRONG code, why it is wrong, and the expert fix.
Each entry follows the format: **Symptom → Wrong Code → Root Cause → Fixed Code → Expert Note**.

When reviewing code, scan for these patterns. When generating code, avoid them.

---

## AP-1: God Service

**Symptom**: A service class with 15+ public methods spanning unrelated concerns.

### ❌ Wrong
```java
@Service
public class OrderService {
    public Order create(OrderRequest req) { ... }
    public void cancel(Long id) { ... }
    public Invoice generateInvoice(Long id) { ... }
    public void sendConfirmationEmail(Long id) { ... }
    public byte[] exportToPdf(Long id) { ... }
    public void syncToErp(Order order) { ... }
    public List<Order> analytics(OrderAnalyticsFilter f) { ... }
    public void applyDiscount(Long id, Discount d) { ... }
}
```

### Root Cause
`OrderService` handles creation, cancellation, invoicing, email, PDF export, ERP sync, analytics, and discounts. Eight reasons to change. Any change risks breaking unrelated behavior.

### ✅ Expert Fix
```java
@Service
public class OrderLifecycleService {
    public Order create(CreateOrderRequest req) { ... }
    public void cancel(Long id) { ... }
}

@Service
public class OrderInvoiceService {
    public Invoice generate(Long orderId) { ... }
    public byte[] exportPdf(Long orderId) { ... }
}

@Service
public class OrderNotificationService {
    @EventListener
    public void onOrderCreated(OrderCreatedEvent e) { ... }
    public void sendConfirmation(Long orderId) { ... }
}
```
**Change impact**: Changing invoice logic now touches only `OrderInvoiceService`. Adding a new notification channel touches only `OrderNotificationService`.

---

## AP-2: Premature Abstraction

**Symptom**: A shared utility with boolean flags controlling behavior for different callers.

### ❌ Wrong
```java
public class OrderFormatter {
    public static String format(Order order, boolean includeTax,
            boolean includeShipping, boolean shortFormat, boolean adminView) {
        var sb = new StringBuilder();
        if (shortFormat) {
            sb.append(order.id());
            if (includeTax) sb.append(" +tax");
            return sb.toString();
        }
        sb.append("Order #").append(order.id());
        if (includeTax) sb.append(" Tax: ").append(order.tax());
        if (includeShipping) sb.append(" Ship: ").append(order.shipping());
        if (adminView) sb.append(" Internal: ").append(order.internalNotes());
        return sb.toString();
    }
}
```

### Root Cause
Four unrelated formatting concerns forced into one method. Each boolean flag represents a caller-specific need that should have been a separate function.

### ✅ Expert Fix
```java
public class OrderShortFormatter {
    public static String format(Order order) {
        return order.id() + " +tax: " + order.tax();
    }
}

public class OrderDetailFormatter {
    public static String format(Order order) {
        return "Order #" + order.id()
            + " Tax: " + order.tax()
            + " Ship: " + order.shipping();
    }
}

public class AdminOrderFormatter {
    public static String format(Order order) {
        return OrderDetailFormatter.format(order)
            + " Internal: " + order.internalNotes();
    }
}
```
**Expert note**: Each caller now depends on exactly one formatter. Deleting a caller means deleting one formatter with zero risk.

---

## AP-3: Swallowed Exception

**Symptom**: Empty catch blocks or logging without rethrowing.

### ❌ Wrong
```java
try {
    paymentGateway.charge(request);
} catch (PaymentException e) {
    log.error("Payment failed", e);
    // order proceeds as if payment succeeded
}
orderService.markAsPaid(orderId);
```

```java
try {
    cache.set(key, value);
} catch (Exception ignored) {}
```

### Root Cause
Silent failures create invisible data corruption. The system believes payment succeeded; the customer was never charged. Bugs like this are discovered weeks later through financial reconciliation.

### ✅ Expert Fix
```java
try {
    paymentGateway.charge(request);
} catch (PaymentException e) {
    throw new PaymentFailedException(orderId, request.amount(), e);
}

// Cache failures should never break business logic but must be observable
try {
    cache.set(key, value);
} catch (Exception e) {
    metrics.cacheWriteFailure.increment();
    log.warn("Cache write failed for key={}, proceeding without cache", key, e);
}
```

---

## AP-4: Entity Leaked to API

**Symptom**: Controller returns JPA entities directly.

### ❌ Wrong
```java
@GetMapping("/orders/{id}")
public Order getOrder(@PathVariable Long id) {
    return orderRepo.findById(id).orElseThrow();
    // Leaks: internal fields, lazy-loading proxies, @Version, all relationships
}
```

### Root Cause
The API contract is now coupled to the database schema. Adding a column changes the API. Lazy-loaded associations trigger N+1 queries during JSON serialization. Sensitive internal fields are exposed.

### ✅ Expert Fix
```java
@GetMapping("/orders/{id}")
public OrderDto getOrder(@PathVariable Long id) {
    return orderRepo.findDtoById(id)
        .orElseThrow(() -> new OrderNotFoundException(id));
}

public record OrderDto(Long id, String status, MoneyDto total,
        List<OrderItemDto> items, Instant createdAt) {}
```
**Expert note**: `OrderDto` is a deliberate API contract. The entity can evolve independently. N+1 is eliminated because the query explicitly joins/fetches needed data.

---

## AP-5: N+1 in Disguise

**Symptom**: A loop that triggers a query per iteration. Usually hidden in stream operations or template rendering.

### ❌ Wrong
```java
var orders = orderRepo.findByStatus(Status.PENDING);
var summaries = orders.stream()
    .map(o -> new OrderSummary(o, paymentRepo.findByOrderId(o.id())))
    .toList(); // 1 + N queries: one for orders, one per order for payment
```

```java
@OneToMany(fetch = FetchType.EAGER) // Every entity load pulls all children
private List<OrderItem> items;
```

### Root Cause
The code structure looks clean (streams, annotations) but hides quadratic database interaction. EAGER fetching makes it invisible — you never see the queries being triggered.

### ✅ Expert Fix
```java
// Option A: Batch fetch
var orderIds = orders.stream().map(Order::id).toList();
var payments = paymentRepo.findByOrderIdIn(orderIds);
var paymentMap = payments.stream()
    .collect(toMap(Payment::orderId, identity()));
var summaries = orders.stream()
    .map(o -> new OrderSummary(o, paymentMap.get(o.id())))
    .toList(); // 2 queries total

// Option B: JOIN FETCH in repository
@Query("SELECT o FROM Order o JOIN FETCH o.payments WHERE o.status = :status")
List<Order> findByStatusWithPayments(@Param("status") Status status);

// Option C: Always LAZY, fetch explicitly
@OneToMany(fetch = FetchType.LAZY)
private List<OrderItem> items;

@EntityGraph(attributePaths = {"items"})
List<Order> findWithItemsByStatus(Status status);
```

---

## AP-6: Mutable Static State

**Symptom**: Mutable static fields or global singletons with setters.

### ❌ Wrong
```java
public class AppConfig {
    public static String DATABASE_URL = "jdbc:postgresql://localhost:5432/dev";
    // Any code anywhere: AppConfig.DATABASE_URL = "something-else";
}

public class UserContext {
    private static final ThreadLocal<User> currentUser = new ThreadLocal<>();
    public static void setUser(User u) { currentUser.set(u); }
    public static User getUser() { return currentUser.get(); }
}
```

### Root Cause
Uncontrolled global mutation makes tests order-dependent, breaks parallel test execution, and creates "works on my machine" bugs. Static mutable state is the #1 enemy of testability.

### ✅ Expert Fix
```java
// Inject configuration. Never use static state for dependencies.
@Service
public class UserService {
    private final DatabaseConfig dbConfig;
    private final UserContextFactory contextFactory;
    // ...
}

// If context really needs to flow implicitly, use a scoped DI approach:
@RequestScope
@Component
public class RequestUserContext {
    private User user;
    // Spring manages lifecycle and cleanup
}
```

---

## AP-7: Magic Number / Magic String

**Symptom**: Numbers and strings with unexplained meaning.

### ❌ Wrong
```java
if (order.total().compareTo(new Money("1000", "CNY")) > 0) { ... }
Thread.sleep(3000);
var client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
if (response.status() == 429) { ... }
```

### ✅ Expert Fix
```java
private static final Money LARGE_ORDER_THRESHOLD = new Money("1000", "CNY");
private static final Duration RETRY_DELAY = Duration.ofSeconds(3);
private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(5);
private static final int HTTP_TOO_MANY_REQUESTS = 429;

if (order.total().compareTo(LARGE_ORDER_THRESHOLD) > 0) { ... }
Thread.sleep(RETRY_DELAY.toMillis());
if (response.status() == HTTP_TOO_MANY_REQUESTS) { ... }
```

---

## AP-8: Missing Idempotency on POST

**Symptom**: POST endpoint that creates resources without idempotency protection.

### ❌ Wrong
```java
@PostMapping("/payments")
public Payment create(@RequestBody PaymentRequest req) {
    return paymentService.charge(req); // Retry = double charge
}
```

### ✅ Expert Fix
```java
@PostMapping("/payments")
public ResponseEntity<?> create(
    @RequestHeader("Idempotency-Key") String idempotencyKey,
    @RequestBody PaymentRequest req
) {
    return idempotencyService.execute(idempotencyKey, req, paymentService::charge);
}
```

---

## AP-9: Exception as Control Flow

**Symptom**: Using try-catch for expected business logic branches.

### ❌ Wrong
```java
public User getUser(String id) {
    try {
        return userRepo.findById(Long.parseLong(id));
    } catch (NumberFormatException e) {
        return userRepo.findByExternalId(id).orElseThrow();
    }
}
```

### ✅ Expert Fix
```java
public User getUser(String id) {
    return parseLong(id)
        .map(userRepo::findById)
        .orElseGet(() -> userRepo.findByExternalId(id))
        .orElseThrow(() -> new UserNotFoundException(id));
}

private Optional<Long> parseLong(String s) {
    try { return Optional.of(Long.parseLong(s)); }
    catch (NumberFormatException e) { return Optional.empty(); }
}
```

---

## AP-10: Thread.sleep in Production Code

**Symptom**: Unconditional sleep as a synchronization or retry mechanism.

### ❌ Wrong
```java
while (!job.isDone()) {
    Thread.sleep(1000); // Busy-wait wasting a thread
}
```

### ✅ Expert Fix
```java
// Use CompletableFuture / CountDownLatch for coordination
job.toFuture().get(5, TimeUnit.MINUTES);

// For retries, use exponential backoff with jitter
var result = retryWithBackoff(() -> client.call(), 3,
    Duration.ofMillis(100), Duration.ofSeconds(5));
```

---

## Quick Scan Checklist

When reviewing generated code, check for these signals:

- [ ] Any class with > 10 public methods? → **God Class (AP-1)**
- [ ] Any method with boolean flag parameters? → **Premature Abstraction (AP-2)**
- [ ] Any `catch` block without `throw` or recovery? → **Swallowed Exception (AP-3)**
- [ ] Any controller returning `@Entity`? → **Entity Leak (AP-4)**
- [ ] Any loop body with repository calls? → **N+1 (AP-5)**
- [ ] Any `static` mutable field? → **Mutable Static (AP-6)**
- [ ] Any bare number/string in business logic? → **Magic Value (AP-7)**
- [ ] Any POST that creates without idempotency key? → **Missing Idempotency (AP-8)**
- [ ] Any `try-catch` for non-exceptional paths? → **Exception as Flow Control (AP-9)**
- [ ] Any `Thread.sleep` outside test code? → **Sleep in Production (AP-10)**
