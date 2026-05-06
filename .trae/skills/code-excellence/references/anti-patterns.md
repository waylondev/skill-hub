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

## AP-17: Long-Running Transaction

**Symptom**: A single database transaction that spans I/O calls, user interactions, or long computations.

### ❌ Wrong
```java
@Transactional
public void processBatch(List<Order> orders) {
    for (var order : orders) {
        orderRepo.save(order);
        paymentGateway.charge(order); // 500ms network call INSIDE transaction
        emailService.sendConfirmation(order); // another 200ms
    }
} // Transaction open for minutes with 1000 orders — connection held, locks held, VACUUM blocked
```

### Root Cause
Database transactions acquire locks and hold connections. The longer they run, the more they block everyone else. External calls (HTTP, email, file I/O) inside transactions are the #1 cause of production deadlocks and connection pool exhaustion.

### ✅ Expert Fix
```java
// 1. Load data outside transaction (read-only is fine)
var orders = orderRepo.findPendingBatch(1000);

// 2. Process each order atomically
for (var order : orders) {
    transactionalProcessor.process(order); // internal: short tx, commits immediately
    // After commit → external calls are safe
    paymentGateway.charge(order);   // outside transaction
    emailService.sendConfirmation(order); // outside transaction
}
```

**Golden rule**: A transaction should be shorter than a coffee break. If it lasts longer than 1 second, reconsider the boundary.

---

## AP-18: Distributed Lock Not Released

**Symptom**: Acquiring a distributed lock (Redis, ZooKeeper) without guaranteed release on failure.

### ❌ Wrong
```java
public void processOrder(Long id) {
    var lock = redis.acquire("lock:order:" + id, Duration.ofSeconds(30));
    // If JVM crashes here — lock held for 30 seconds, nobody else can process
    doWork(id);
    redis.release(lock); // May never execute
}
```

### Root Cause
Distributed locks must have automatic expiry. If the lock holder crashes before release, the lock must expire on its own. Manual release without expiry = permanent lock on crash.

### ✅ Expert Fix
```java
// Redisson — automatic lease renewal + TTL expiry
var lock = redisson.getFairLock("lock:order:" + id);
try {
    if (lock.tryLock(2, 30, TimeUnit.SECONDS)) { // wait 2s, hold max 30s
        doWork(id);
    }
} finally {
    if (lock.isHeldByCurrentThread()) {
        lock.unlock();
    }
}
// If process crashes, Redis key expires after 30s automatically.

// Alternative: SET NX with TTL
var ok = redis.set("lock:order:" + id, instanceId, "NX", "EX", 30);
if (ok) {
    try { doWork(id); }
    finally { if (redis.get("lock:order:" + id).equals(instanceId)) redis.del("lock:order:" + id); }
}
```

---

## AP-19: Cache Avalanche/Breakdown/Penetration

**Symptom**: Cache patterns that collapse under specific failure modes.

### ❌ Wrong — Three Cache Disasters
```java
// Disaster 1: Cache Avalanche — all keys expire at the same time
cache.set("product:" + id, data, Duration.ofHours(1));
// 100,000 keys expire simultaneously → DB crushed by 100,000 concurrent misses

// Disaster 2: Cache Breakdown — hot key expires during peak
cache.set("hot-promotion", data, Duration.ofMinutes(5));
// Hot item cache expires → ALL traffic hits DB for this one key → DB collapses

// Disaster 3: Cache Penetration — querying non-existent data
// Attackers query ghost IDs: 999999, 999998, 999997...
// Each query misses cache → hits DB → DB overloaded by useless queries
```

### ✅ Expert Fix
```java
// Fix 1: Random jitter on TTL — no simultaneous expiry
var baseTtl = Duration.ofHours(1);
var jitter = Duration.ofSeconds(random.nextInt(600)); // 0-10 min random offset
cache.set(key, data, baseTtl.plus(jitter));

// Fix 2: Hot key mutex — only one thread rebuilds the cache
public Product getHotProduct(String key) {
    var cached = cache.get(key);
    if (cached != null) return cached;

    // Only ONE thread acquires the rebuild lock
    var lock = cache.acquireLock("rebuild:" + key, Duration.ofSeconds(5));
    if (lock) {
        try {
            cached = db.query(key);
            cache.set(key, cached, Duration.ofMinutes(5).plus(Duration.ofSeconds(random.nextInt(60))));
            return cached;
        } finally { cache.releaseLock("rebuild:" + key); }
    }

    // Other threads: wait briefly, retry cache, or return stale
    sleep(50);
    cached = cache.get(key);
    if (cached != null) return cached;
    return getStaleValue(key); // better than crashing
}

// Fix 3: Bloom filter for non-existent keys — reject before hitting DB
if (!bloomFilter.mightContain(id)) {
    return null; // definitely does NOT exist — skip DB
}
// For genuinely non-existent keys: cache a NULL marker with short TTL
cache.set("user:" + id, NullMarker.INSTANCE, Duration.ofMinutes(1));
```

---

## AP-20: Logging Sensitive Data

**Symptom**: Secrets, passwords, or PII accidentally leaked through logging or serialization.

### ❌ Wrong
```java
log.info("Processing payment: {}", paymentRequest);
// paymentRequest.toString() includes credit card number, CVV

log.info("User authenticated: {}", user);
// user.toString() includes hashed password, API tokens

log.info("Request: {}", request);
// Real client IP, phone numbers, ID numbers logged as INFO
```

### Root Cause
`toString()` on domain objects often includes everything. Structured logging of entire objects is dangerous unless you explicitly control what gets logged.

### ✅ Expert Fix
```java
// 1. Exclude sensitive fields from toString()
public record CreatePaymentRequest(
    Long orderId,
    @JsonIgnore @ToStringExclude String cardNumber,
    @JsonIgnore @ToStringExclude String cvv
) {}

// 2. Log only what you need
log.info("Processing payment for order {}", req.orderId());
// NOT: log.info("Processing payment: {}", req);

// 3. Mask sensitive data before logging
public String maskCard(String card) {
    return card.substring(0, 4) + "****" + card.substring(card.length() - 4);
}

// 4. Separate audit log (PII OK, secured) from operational log (no PII)
auditLog.info("User {} accessed payment for order {}", userId, orderId); // secured storage
appLog.info("Order {} payment processed", orderId); // no user info
```

---

## AP-21: Missing Timeout on External Call

**Symptom**: External HTTP/database/message calls without timeout — thread hangs forever.

### ❌ Wrong
```java
var client = HttpClient.newHttpClient(); // DEFAULT: infinite timeout
client.send(request, BodyHandlers.ofString()); // thread blocked forever if service hangs

RestTemplate rest = new RestTemplate(); // DEFAULT: infinite timeout
rest.getForEntity("http://slow-service/api", String.class);
```

### Root Cause
Every external call can hang (network partition, service GC pause, deadlock). Without a timeout, the calling thread joins the zombie army, eventually exhausting the thread pool or connection pool.

### ✅ Expert Fix
```java
// Java 11+ HttpClient — always set connect + request timeout
var client = HttpClient.newBuilder()
    .connectTimeout(Duration.ofSeconds(3))    // TCP handshake timeout
    .build();

client.send(request, BodyHandlers.ofString(),
    HttpResponse.BodyHandlers.ofString(),
    HttpRequest.newBuilder().timeout(Duration.ofSeconds(5)).build()
);

// RestTemplate with timeout
var factory = new SimpleClientHttpRequestFactory();
factory.setConnectTimeout(Duration.ofSeconds(3));
factory.setReadTimeout(Duration.ofSeconds(5));
var rest = new RestTemplate(factory);

// Spring Boot RestClient (3.2+)
var client = RestClient.builder()
    .requestFactory(new JdkClientHttpRequestFactory(
        HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(3)).build()
    ))
    .build();
```

---

## AP-22: Circular Dependency

**Symptom**: Two or more classes depend on each other, creating a dependency cycle.

### ❌ Wrong
```java
@Service
public class OrderService {
    private final PaymentService paymentService; // OrderService → PaymentService

    public void process(Order order) { paymentService.charge(order); }
}

@Service
public class PaymentService {
    private final OrderService orderService; // PaymentService → OrderService

    public void charge(Order order) { orderService.updateStatus(order, PAID); }
} // Circular dependency — untestable, hard to reason about, breaks on refactoring
```

### Root Cause
Circular dependencies hide a missing abstraction. Neither service truly owns the flow — they're locked in a death grip.

### ✅ Expert Fix
```java
// Option A: Extract the orchestration into a third service
@Service
public class OrderCheckoutOrchestrator {
    private final OrderService orderService;
    private final PaymentService paymentService;

    public void checkout(Long orderId) {
        var order = orderService.get(orderId);
        paymentService.charge(order);
        orderService.markAsPaid(orderId);
        // Flow direction: Orchestrator → OrderService, Orchestrator → PaymentService
        // No cycle. Single responsibility: checkout flow.
    }
}

// Option B: Use events to break the cycle
@Service
public class PaymentService {
    private final ApplicationEventPublisher events;

    public void charge(Order order) {
        gateway.charge(order);
        events.publish(new PaymentCompletedEvent(order.id())); // fire and forget
    }
}
// OrderService listens, no back-dependency
```

---

## AP-23: God Method (Long Method)

**Symptom**: A single method exceeding 60 lines, mixing multiple levels of abstraction.

### ❌ Wrong
```java
public OrderResult checkout(CheckoutRequest req) {
    // 10 lines: validate cart
    if (req.cart() == null) throw ...;
    for (var item : req.cart()) { if (item.quantity() <= 0) throw ...; }

    // 15 lines: calculate total + discount
    var total = req.cart().stream().map(...).reduce(...);
    if (req.hasPromoCode()) {
        var promo = promoRepo.findActive(req.promoCode());
        total = total.subtract(promo.discount(total));
    }

    // 20 lines: payment processing
    var paymentReq = new PaymentRequest(total, req.paymentMethod());
    var response = paymentGateway.charge(paymentReq);
    if (!response.isSuccess()) { ... }

    // 10 lines: create order
    var order = new Order(req.userId(), req.cart(), total);
    orderRepo.save(order);

    // 10 lines: send notifications
    emailService.sendConfirmation(order);
    smsService.send(order.user().phone(), "Order confirmed");

    // 5 lines: build response
    return new OrderResult(order.id(), total, response.transactionId());
} // 70+ lines, four levels of abstraction
```

### Root Cause
Long methods violate the "single level of abstraction" principle. They are hard to test (which branch does this line belong to?), hard to debug (which part failed?), and impossible to reuse.

### ✅ Expert Fix
```java
// Each method at ONE level of abstraction, ~5-15 lines each
public OrderResult checkout(CheckoutRequest req) {
    validateCart(req);
    var pricing = calculatePricing(req);
    var payment = capturePayment(req, pricing);
    var order = createOrder(req, pricing, payment);
    notifyCustomer(order);
    return buildResult(order, payment);
}

private void validateCart(CheckoutRequest req) {
    if (req.cart() == null || req.cart().isEmpty())
        throw new InvalidCartException("Cart is empty");
    for (var item : req.cart()) {
        if (item.quantity() <= 0)
            throw new InvalidCartException("Invalid quantity for " + item.sku());
    }
}

private Pricing calculatePricing(CheckoutRequest req) {
    var subtotal = pricingEngine.calculate(req.cart());
    return req.promoCode() != null
        ? discountEngine.apply(subtotal, req.promoCode())
        : new Pricing(subtotal, Money.ZERO, subtotal);
}
```

---

## AP-24: Deep Inheritance Hierarchy

**Symptom**: Inheritance chains 3+ levels deep, creating rigid and fragile class structures.

### ❌ Wrong
```java
class Entity { protected Long id; protected LocalDateTime createdAt; }
class AuditableEntity extends Entity { protected String createdBy; protected String updatedBy; }
class VersionedEntity extends AuditableEntity { protected Long version; }
class SoftDeletableEntity extends VersionedEntity { protected boolean deleted; }
class Order extends SoftDeletableEntity { /* finally, business logic */ }
// 4 levels of inheritance just to compose orthogonal concerns
```

### Root Cause
Deep inheritance chains force orthogonal concerns (auditing, versioning, soft-delete) into a linear hierarchy. The Fragile Base Class Problem: changing any ancestor class potentially breaks every descendant.

### ✅ Expert Fix
```java
// Composition — each concern is a separate collaborator
class Order {
    private final OrderId id;
    private final AuditInfo audit;      // composition
    private final Version version;      // composition
    private SoftDeleteStatus deleted;   // composition
    // Order owns ALL behavior; no fragile base class
}

// Each concern is its own, reusable component
record AuditInfo(String createdBy, String updatedBy, Instant createdAt, Instant updatedAt) {}
record Version(long value) {}
enum SoftDeleteStatus { ACTIVE, DELETED }

// Cross-cutting concerns via AOP or decorators where needed
@Auditable
@Versioned
public class Order { /* pure business logic */ }
```

---

## AP-25: Non-Atomic Multi-Step Mutation

**Symptom**: A multi-step state change where individual steps can succeed or fail independently, leaving the system in a partial state.

### ❌ Wrong
```java
// Step 1: write to primary DB (succeeds)
userRepo.save(user);

// Step 2: write to cache (fails — network blip)
cache.set("user:" + user.id(), user, Duration.ofMinutes(10));

// Step 3: sync to search index (fails — ES overloaded)
searchIndex.index(user);

// Result: DB has the user, but cache has stale data, search is missing the user.
// Three different views of reality. Fixing this requires manual reconciliation.
```

### Root Cause
Without an atomicity strategy, partial failure leaves the system in an inconsistent state. Each downstream system sees a different version of truth, and no single place records what actually happened vs what should have happened.

### ✅ Expert Fix
```java
// Strategy 1: DB as single source of truth + async eventual consistency
@Transactional
public void updateUser(User user) {
    userRepo.save(user); // the ONLY synchronous step

    // Publish event — downstream consumers will eventually sync
    outboxRepo.save(new OutboxEvent("UserUpdated", new UserUpdatedPayload(user.id())));
    // Cache invalidation + search reindex happen asynchronously.
    // If any fails, retry from outbox. Eventual consistency guaranteed.
}

// Strategy 2: Saga with compensating actions
public void updateUser(User user, Cache cache, SearchIndex index) {
    try {
        userRepo.save(user);
        try {
            index.index(user);
        } catch (Exception e) {
            // index failed → compensate by reverting? No!
            // Instead, log + retry async. Don't roll back the DB.
            outbox.record(UserIndexed(user.id()), "pending");
        }
        try { cache.delete("user:" + user.id()); }
        catch (Exception e) { metrics.cacheOpFailure.increment(); }
        // Cache miss = slower, but correct (reads from DB)
    }
    // The system is always consistent from the DB's perspective.
    // Cache and search are eventually consistent.
}
```

---

## AP-26: Pagination Without Upper Bound

**Symptom**: API pagination parameters accepting arbitrarily large page sizes.

### ❌ Wrong
```java
@GetMapping("/orders")
public Page<Order> list(@RequestParam(defaultValue = "0") int page,
                        @RequestParam(defaultValue = "20") int size) {
    return orderService.list(PageRequest.of(page, size));
    // Attacker: ?page=0&size=10000000 → DB OOM, app OOM, GC death spiral
}
```

### Root Cause
Unbounded pagination is a DoS vector. Loading 10 million rows into memory will OOM the service. Even if the DB survives, serializing the response will exhaust heap.

### ✅ Expert Fix
```java
@GetMapping("/orders")
public Page<Order> list(@RequestParam(defaultValue = "0") @Min(0) int page,
                        @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    return orderService.list(PageRequest.of(page, size));
    // Max 100 per page. Attacker needs 100,000 requests to get 10M records.
    // This is now rate-limited, not memory-exploded.
}

// For truly large datasets — use cursor-based pagination (no offset)
@GetMapping("/orders/cursor")
public CursorPage<Order> listCursor(
    @RequestParam(required = false) String cursor, // base64 encoded last ID
    @RequestParam(defaultValue = "50") @Max(200) int limit
) {
    return orderService.listAfter(cursor, limit);
    // WHERE id > :lastId ORDER BY id LIMIT :limit
    // Consistent across inserts/deletes. No skipped or duplicated rows.
}
```

---

## AP-28: TOCTOU Race Condition (Time-of-Check to Time-of-Use)

**Symptom**: A condition is checked, then later acted upon — but the state may have changed between check and use.

### ❌ Wrong
```java
// Race Condition: concurrent requests both pass the check, both create duplicates
if (!orderRepo.existsByIdempotencyKey(key)) {  // CHECK — key doesn't exist yet
    orderRepo.save(new Order(key));            // USE — but another thread just inserted!
}

// Defensive programming missing — division by zero
public double calculateDiscountRate(Money discount, Money total) {
    return discount.amount().doubleValue() / total.amount().doubleValue(); // total=0 → ArithmeticException
}

// Missing null check on external data
public String formatAddress(User user) {
    return user.getAddress().getCity() + ", " + user.getAddress().getState();
    // getAddress() returns null for new users → NullPointerException
}
```

### Root Cause

TOCTOU vulnerabilities occur when a check and subsequent action are not atomic. In concurrent systems, another thread/process can change the state between the check and the use. This is the root cause of duplicate payments, double bookings, and race-condition data corruption.

### ✅ Expert Fix — Atomic Operations

```java
// Fix 1: Database-level unique constraint + handle constraint violation
@Transactional
public Order createOrder(CreateOrderRequest req) {
    try {
        return orderRepo.save(Order.builder()
            .idempotencyKey(req.idempotencyKey())
            .userId(req.userId())
            .build());
    } catch (DataIntegrityViolationException e) {
        // Unique constraint on idempotency_key was violated — order already exists
        return orderRepo.findByIndempotencyKey(req.idempotencyKey())
            .orElseThrow(() -> new IllegalStateException("Unexpected state"));
    }
}

// Schema must enforce:
// ALTER TABLE orders ADD CONSTRAINT uq_idempotency_key UNIQUE (idempotency_key);

// Fix 2: Atomic check-and-create at DB level
@Query(value = """
    INSERT INTO orders (idempotency_key, user_id, status)
    VALUES (:key, :userId, 'PENDING')
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING *
    """, nativeQuery = true)
Optional<Order> findOrCreateByIndempotencyKey(@Param("key") String key,
                                                @Param("userId") Long userId);

// Fix 3: Optimistic locking for concurrent updates
@Entity
public class Order {
    @Id private Long id;
    @Version private Long version;  // JPA optimistic locking
    // On concurrent update: OptimisticLockException — retry or reject
}

// Defensive programming: guard against zero/null
public double calculateDiscountRate(Money discount, Money total) {
    Objects.requireNonNull(discount, "discount must not be null");
    Objects.requireNonNull(total, "total must not be null");
    if (total.amount().compareTo(BigDecimal.ZERO) == 0) {
        return 0.0; // zero total = zero discount rate, not division by zero
    }
    return discount.amount().doubleValue() / total.amount().doubleValue();
}

// Null-safe chaining with Optional
public String formatAddress(User user) {
    return Optional.ofNullable(user)
        .map(User::getAddress)
        .map(a -> a.getCity() + ", " + a.getState())
        .orElse("Address not provided");
}
```

**Key Principles**:
1. **Database constraints are the last line of defense** — unique constraints, NOT NULL, foreign keys
2. **Check-and-act must be atomic** — `INSERT ... ON CONFLICT`, `SELECT ... FOR UPDATE`, distributed locks
3. **Defensive programming** — validate inputs, handle edge cases, fail fast with clear messages

---

## AP-29: Pagination Without Offset Safety

**Symptom**: Using OFFSET/LIMIT pagination that becomes slow on deep pages.

### ❌ Wrong
```java
// OFFSET 1000000, LIMIT 20 — DB scans 1,000,020 rows to return 20
@Query("SELECT o FROM Order o ORDER BY o.createdAt DESC")
Page<Order> findOrders(Pageable pageable); // attacker: page=50000&size=20 → OOM
```

### Root Cause

OFFSET doesn't skip rows efficiently — the database still reads and discards all skipped rows. At deep offsets, this becomes O(n) per query. Additionally, result set changes between pages if data is inserted/deleted during pagination.

### ✅ Expert Fix — Cursor-Based Pagination

```java
// Cursor pagination — O(log n) via index, consistent across changes
@Query(value = """
    SELECT o.* FROM orders o
    WHERE o.created_at < :cursor
       OR (o.created_at = :cursor AND o.id < :cursorId)
    ORDER BY o.created_at DESC, o.id DESC
    LIMIT :limit
    """, nativeQuery = true)
List<Order> findAfterCursor(@Param("cursor") LocalDateTime cursor,
                            @Param("cursorId") Long cursorId,
                            @Param("limit") int limit);

// Response includes next cursor for the caller
public record CursorPage<T>(
    List<T> items,
    @Nullable String nextCursor,  // base64 encoded (createdAt, id)
    boolean hasNextPage
) {}
```

**OFFSET vs Cursor Comparison**:

| Metric | OFFSET/LIMIT | Cursor-Based |
|---|---|---|
| Deep page performance | O(n) — degrades with page depth | O(log n) — consistent |
| Consistency during pagination | Skips/duplicates rows if data changes | Consistent — based on last seen row |
| Total count available | Yes — requires separate COUNT query | No — requires separate query |
| Best for | Small result sets, admin dashboards | Large datasets, infinite scroll |

---

## AP-30: Missing Circuit Breaker on External Calls

**Symptom**: External service calls without failure isolation — one slow dependency drags down the entire system.

### ❌ Wrong
```java
// No circuit breaker — if payment service is slow, all threads block
public PaymentResult processPayment(Order order) {
    return paymentGateway.charge(order);  // 10s timeout → thread pool exhaustion under load
}

// No fallback — service completely unavailable
public ProductInfo getProduct(Long id) {
    return catalogService.findById(id); // catalog down → product page returns 500
}
```

### Root Cause

Without a circuit breaker, a failing or slow external service causes cascading failures. Threads pile up waiting for timeouts, connection pools exhaust, and the entire application becomes unresponsive.

### ✅ Expert Fix — Resilience4j Circuit Breaker

```java
@CircuitBreaker(name = "paymentService", fallbackMethod = "paymentFallback")
@Retry(name = "paymentService")
@TimeLimiter(name = "paymentService")
public PaymentResult processPayment(Order order) {
    return paymentGateway.charge(order);
}

// Fallback: degrade gracefully instead of failing completely
public PaymentResult paymentFallback(Order order, Exception e) {
    log.warn("Payment service unavailable, queuing for retry: {}", e.getMessage());
    paymentQueue.enqueue(order);  // async retry via message queue
    return PaymentResult.pending(order.id());  // inform caller it's processing
}

// Configuration
resilience4j:
  circuitbreaker:
    instances:
      paymentService:
        failureRateThreshold: 50        # open circuit when 50% calls fail
        slowCallRateThreshold: 80       # also count slow calls (> 2s)
        slowCallDurationThreshold: 2s
        permittedNumberOfCallsInHalfOpenState: 3
        slidingWindowSize: 10
        minimumNumberOfCalls: 5
  retry:
    instances:
      paymentService:
        maxAttempts: 3
        waitDuration: 500ms
        retryExceptions:
          - java.net.SocketTimeoutException
  timelimiter:
    instances:
      paymentService:
        timeoutDuration: 3s             # fail fast, don't wait forever
        cancelRunningFuture: true
```

**Circuit Breaker States**:

| State | Behavior | Transition |
|---|---|---|
| CLOSED | Normal operation — requests pass through | → OPEN when failure rate exceeds threshold |
| OPEN | Requests fail immediately — no calls to external service | → HALF_OPEN after wait duration |
| HALF_OPEN | Limited test requests to check if service recovered | → CLOSED if test succeeds, → OPEN if fails |

---

## AP-27: Untrusted Data Passed to Dangerous Sink

### ❌ Wrong
```java
// SQL Injection
String query = "SELECT * FROM orders WHERE user_id = " + request.getParameter("userId");
jdbc.execute(query); // ?userId=1 OR 1=1 → dumps all orders

// OS Command Injection
Runtime.exec("ping " + host); // host = "; rm -rf /" → catastrophe

// XSS
return "<div>Welcome, " + userName + "</div>"; // userName = "<script>stealCookies()</script>"

// Insecure Deserialization
var obj = deserialize(request.getBody()); // attacker crafts malicious serialized object → RCE
```

### Root Cause
Mixing data with code is the fundamental security sin. User data must NEVER be concatenated into commands, queries, or markup. The boundary between "code" and "data" must be absolute.

### ✅ Expert Fix
```java
// SQL: Parameterized queries ONLY
jdbc.query("SELECT * FROM orders WHERE user_id = ?", userId);
// ORM: Use named parameters, never string concatenation
orderRepo.findByUserId(userId); // Spring Data JPA — safe by default

// OS: Avoid Runtime.exec entirely. Use ProcessBuilder with separate args.
var pb = new ProcessBuilder("ping", "-c", "3", validatedHost);
// Or better: no shell at all. Java's InetAddress for ping.

// XSS: Escape ALL user content in output
// Server-side rendering: use template engine auto-escaping (Thymeleaf, etc.)
// API: return raw data, let the SPA framework (React/Vue) handle escaping

// Deserialization: NEVER deserialize untrusted data
// Use formats that ONLY carry data: JSON (Jackson), Protobuf, Avro
// If you MUST use Java serialization: whitelist allowed classes
ObjectInputFilter.Config.createFilter("com.example.*;!*");
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
- [ ] Any transaction containing external I/O? → **Long-Running Transaction (AP-17)**
- [ ] Any distributed lock without automatic expiry? → **Lock Not Released (AP-18)**
- [ ] Any cache with uniform TTL or missing hot-key protection? → **Cache Disaster (AP-19)**
- [ ] Any `log.info(entireObject)` on sensitive objects? → **Logging Secrets (AP-20)**
- [ ] Any external call without explicit timeout? → **Missing Timeout (AP-21)**
- [ ] Any A → B and B → A dependency pair? → **Circular Dependency (AP-22)**
- [ ] Any method > 60 lines? → **God Method (AP-23)**
- [ ] Any inheritance chain > 3 levels? → **Deep Inheritance (AP-24)**
- [ ] Any multi-step mutation without Saga or outbox? → **Non-Atomic Mutation (AP-25)**
- [ ] Any pagination without @Max on page size? → **Unbounded Pagination (AP-26)**
- [ ] Any string concatenation for SQL / OS command / HTML? → **Injection (AP-27)**
- [ ] Any check-then-act without atomicity? → **TOCTOU Race Condition (AP-28)**
- [ ] Any OFFSET pagination on tables > 100K rows? → **Deep Offset Pagination (AP-29)**
- [ ] Any external call without circuit breaker? → **Missing Circuit Breaker (AP-30)**
