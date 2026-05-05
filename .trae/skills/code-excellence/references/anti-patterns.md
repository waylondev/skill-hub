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

## AP-11: Ignored Error Return (Go)

**Symptom**: Using `_` to discard error returns from functions that can fail.

### ❌ Wrong
```go
result, _ := json.Marshal(data) // If marshaling fails, result is nil — silent corruption
os.WriteFile("config.json", data, 0644) // Error ignored — file not written, nobody knows
_, _ = fmt.Fprintf(w, "Hello") // Network error ignored
```

### Root Cause
Go's error-returning convention makes it easy to ignore errors with `_`. But the error exists for a reason — the operation may have failed, and continuing as if it succeeded causes silent data corruption or loss.

### ✅ Expert Fix
```go
result, err := json.Marshal(data)
if err != nil {
    return fmt.Errorf("marshal config: %w", err)
}

if err := os.WriteFile("config.json", data, 0644); err != nil {
    return fmt.Errorf("write config: %w", err)
}

_, err = fmt.Fprintf(w, "Hello")
if err != nil {
    log.Printf("failed to write response: %v", err)
}
```

---

## AP-12: God main.go (Go)

**Symptom**: Everything crammed into `main()` — HTTP handlers, business logic, DB connections, middleware — all in one 500-line file.

### ❌ Wrong
```go
func main() {
    db, err := sql.Open("postgres", os.Getenv("DB_URL"))
    if err != nil { log.Fatal(err) }

    http.HandleFunc("/users", func(w http.ResponseWriter, r *http.Request) {
        // 100+ lines of business logic + SQL + JSON rendering
    })
    http.HandleFunc("/orders", func(w http.ResponseWriter, r *http.Request) {
        // another 100+ lines
    })
    http.ListenAndServe(":8080", nil)
}
```

### Root Cause
Go's simplicity can become a trap: everything "works" in `main()`. But this makes testing impossible, hides dependencies, and grows without bounds.

### ✅ Expert Fix
```go
// cmd/server/main.go — thin entry point
func main() {
    cfg := config.Load()
    db := database.New(cfg.DatabaseURL)
    userRepo := repository.NewUserRepository(db)
    orderRepo := repository.NewOrderRepository(db)
    userService := service.NewUserService(userRepo)
    orderService := service.NewOrderService(orderRepo, userService)
    router := handler.NewRouter(userService, orderService)
    server.Start(router, cfg.Addr)
}

// internal/handler/users.go — handlers only
func (h *UserHandler) GetUser(w http.ResponseWriter, r *http.Request) {
    id := r.PathValue("id")
    user, err := h.svc.Find(id)
    if err != nil { respondError(w, err); return }
    respondJSON(w, http.StatusOK, user)
}
```

---

## AP-13: ORM Model Leaked to API (Python)

**Symptom**: FastAPI/Flask endpoint directly returns SQLAlchemy models.

### ❌ Wrong
```python
@app.get("/users/{user_id}")
def get_user(user_id: int, db: Session = Depends(get_db)):
    return db.query(User).filter(User.id == user_id).first()
    # Leaks: hashed_password, internal flags, all relationships
```

### Root Cause
SQLAlchemy models contain database-specific internals. Returning them directly couples your API to your DB schema, exposes sensitive fields, and triggers lazy-loaded relationships (N+1).

### ✅ Expert Fix
```python
class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    email: str
    created_at: datetime

@app.get("/users/{user_id}", response_model=UserResponse)
def get_user(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(404, "User not found")
    return user  # Pydantic serializes only UserResponse fields
```

---

## AP-14: Global Mutable State (Python)

**Symptom**: Module-level mutable variables used as shared state.

### ❌ Wrong
```python
# config.py
DATABASE_URL = "sqlite:///dev.db"
cache = {}

# anywhere: config.DATABASE_URL = "something-else"
# anyone can modify config.cache at any time
```

### Root Cause
Python modules are singletons. Module-level mutable state is global, uncontrolled, and makes testing order-dependent.

### ✅ Expert Fix
```python
class Settings(BaseSettings):
    database_url: str = "sqlite:///dev.db"

settings = Settings()  # immutable after construction

# For caching, use dependency injection
class CacheService:
    def __init__(self): self._cache: dict = {}
    def get(self, key): ...
    def set(self, key, value): ...
```

---

## AP-15: Bare Except in Python

**Symptom**: `except:` or `except Exception:` that catches everything including `KeyboardInterrupt` and `SystemExit`.

### ❌ Wrong
```python
try:
    process_order(order)
except Exception:
    pass  # Silent failure — order lost forever

try:
    run_server()
except:  # Catches KeyboardInterrupt — Ctrl+C won't work!
    print("Error occurred")
```

### Root Cause
Bare `except` catches `KeyboardInterrupt`, `SystemExit`, and `GeneratorExit` — exceptions that are meant to terminate the process.

### ✅ Expert Fix
```python
try:
    process_order(order)
except OrderProcessingError as e:
    logger.error("Failed to process order %s: %s", order.id, e)
    raise

# Or for truly unexpected errors:
try:
    process_order(order)
except Exception as e:
    logger.critical("Unexpected error processing %s", order.id, exc_info=True)
    raise  # re-raise — don't swallow
```

---

## AP-16: Data Class for JPA Entity (Kotlin)

**Symptom**: Using Kotlin `data class` for JPA/Hibernate entities.

### ❌ Wrong
```kotlin
@Entity
data class Order(
    @Id val id: Long = 0,
    val status: String,
    val items: MutableList<OrderItem>
)
// data class generates equals/hashCode including ALL properties
// Hibernate proxies break this — detached entities fail equality checks
```

### Root Cause
`data class` auto-generates `equals`/`hashCode` based on ALL constructor properties. Hibernate proxies for lazy-loaded associations produce false negatives. Also, JPA needs a no-arg constructor which `data class` doesn't provide by default.

### ✅ Expert Fix
```kotlin
@Entity
class Order(
    @Id @GeneratedValue var id: Long = 0,
    var status: String = "",
    @OneToMany(mappedBy = "order", fetch = FetchType.LAZY)
    var items: MutableList<OrderItem> = mutableListOf()
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is Order) return false
        return id != 0L && id == other.id
    }
    override fun hashCode(): Int = if (id != 0L) id.hashCode() else System.identityHashCode(this)
}
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
- [ ] Any `_, _ = ` or discarded error in Go? → **Ignored Error (AP-11)**
- [ ] Any Go `main()` with > 50 lines? → **God main.go (AP-12)**
- [ ] Any Python endpoint returning ORM model? → **ORM Leak (AP-13)**
- [ ] Any Python module-level mutable variable? → **Global Mutable State (AP-14)**
- [ ] Any Python `except:` without specific exception? → **Bare Except (AP-15)**
- [ ] Any Kotlin `data class` with `@Entity`? → **Data Class Entity (AP-16)**
