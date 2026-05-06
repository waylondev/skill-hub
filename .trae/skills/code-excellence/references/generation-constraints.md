# Generation Constraints

## Purpose

Defines the 15 mandatory generation constraints (C1-C15) that distinguish production-ready code from merely "working" code.
Each constraint includes a precise definition, applicable scenarios, violation/compliant code examples, and an enforcement strategy
for automated or manual verification. These constraints are the executable quality gates referenced by the Pre-Generation Checklist
and the RIPER-5 REFLECT review phase.

---

## C1: Input Validation at Boundary

### Definition

Every external input must be validated at the exact point where it crosses the system boundary — controller endpoints,
message listeners, CLI entry points, file parsers, and public API methods. Validation includes structural checks
(non-null, non-empty, valid range, valid format) and business rule checks, with rejection occurring **before** the
input propagates to any internal component. Deferred validation allows bad data to spread, making the source of
corruption untraceable.

### Applicable Scenarios

| Applies | May Skip |
|---------|----------|
| Public API endpoints (REST, gRPC, GraphQL) | Internal method calls between trusted components in the same bounded context |
| Message queue consumers (Kafka, RabbitMQ) | Private helper methods whose callers already validate |
| File upload / file parsing boundaries | Configuration values already validated at startup (C12) |
| CLI command arguments | |
| User-facing form submissions | |

### ❌ Violation Example

```java
@PostMapping("/orders")
public Order create(@RequestBody CreateOrderRequest req) {
    return orderService.create(req);  // no validation at boundary
}

// 200 lines later, deep in the service layer:
public Order create(CreateOrderRequest req) {
    if (req.userId() == null)           // validation buried — error origin untraceable
        throw new IllegalArgumentException("userId required");
    if (req.items() == null || req.items().isEmpty())  // null pointer possible earlier
        throw new IllegalArgumentException("items required");
    // ...
}
```

### ✅ Compliant Example

```java
@PostMapping("/orders")
public Order create(@Valid @RequestBody CreateOrderRequest req) {
    // javax.validation / Jakarta Bean Validation at the boundary
    return orderService.create(req);
}

public record CreateOrderRequest(
    @NotNull(message = "userId is required")
    @Positive(message = "userId must be positive")
    Long userId,

    @NotEmpty(message = "items must not be empty")
    List<@Valid OrderItemRequest> items,

    @Size(max = 500, message = "notes must not exceed 500 characters")
    String notes
) {}
```

### Enforcement Strategy

- **Static analysis**: Enable `javax.validation` / Bean Validation annotations with a global `@Validated` interceptor or Spring's `MethodValidationPostProcessor`.
- **ArchUnit test**: Assert that every `@RestController` method parameter carries `@Valid` or explicit validation call.
- **Code review checklist**: No raw `@RequestBody` without `@Valid`; no `HttpServletRequest.getParameter()` without immediate sanitization.
- **Fuzzing test**: Send null fields, empty collections, oversized strings, negative numbers to every endpoint — expect `400 Bad Request` with structured error, never `500`.

---

## C2: No Silent Failures

### Definition

Every error path must produce an observable outcome: a thrown exception, a structured error response, an incremented metric counter,
or a logged diagnostic. Empty `catch` blocks, discarded error return values, and fallback logic that masks the original failure
are strictly prohibited. The system must never continue execution as if a failed operation succeeded — this produces invisible
data corruption that surfaces only during audits or reconciliation, often weeks later.

### Applicable Scenarios

| Applies | May Skip |
|---------|----------|
| All `catch` blocks in production code | Non-critical best-effort operations where metrics are emitted instead (cache writes, telemetry flushes) |
| All Go `err` return values | |
| All async callbacks / `CompletableFuture` chains | |
| All I/O operations (network, file, DB) | |

### ❌ Violation Example

```java
// Silent swallow — system proceeds as if payment succeeded
try {
    paymentGateway.charge(request);
} catch (PaymentException e) {
    log.error("Payment failed", e);
}
orderService.markAsPaid(orderId);  // corrupt: order marked paid, customer never charged

// Silent discard — operation lost entirely
try {
    cache.set(key, value);
} catch (Exception ignored) {}
```

### ✅ Compliant Example

```java
// Business-critical failure: escalate immediately
try {
    paymentGateway.charge(request);
} catch (PaymentException e) {
    throw new PaymentFailedException(orderId, request.amount(), e);
}

// Best-effort failure: observable but non-blocking
try {
    cache.set(key, value);
} catch (Exception e) {
    metrics.cacheWriteFailures.increment();
    log.warn("Cache write failed for key={}, proceeding without cache", key, e);
}
```

### Enforcement Strategy

- **Static analysis**: SpotBugs rule `DE_MIGHT_IGNORE` (empty catch blocks); PMD rule `EmptyCatchBlock`.
- **ArchUnit test**: Forbid `catch (Exception e) { log.error(...); }` without `throw` or compensating action.
- **Go linting**: `errcheck` linter to detect all discarded error returns. CI must pass with zero `errcheck` warnings.
- **Code review checklist**: Every `catch` block must contain one of: `throw`, `metrics.xxx.increment()`, `log.warn(...)` with context, or a documented compensating transaction.

---

## C3: Always Include Tests

### Definition

Every non-trivial unit of behavior — methods, services, API endpoints — must ship with corresponding automated tests.
A non-trivial unit is any code path containing branching logic (`if`, `switch`, pattern matching), exception handling,
or state mutation. The minimum test suite must cover the **happy path** (normal operation), at least one **error path**
(how failure manifests), and at least one **edge case** (boundary values, empty collections, null inputs where applicable).
Tests are generated alongside the implementation, not appended as an afterthought.

### Applicable Scenarios

| Applies | May Skip |
|---------|----------|
| All public service methods | Pure DTOs / records with no logic |
| All API endpoint handlers | Framework-generated code (Lombok `@Data`, MapStruct mappers — test the mapper config, not the generated bytes) |
| All repository custom queries | Trivial delegation methods (e.g., `this.repo.save(entity)`) |
| All utility/helper methods with business logic | |
| All validation/calculation logic | |

### ❌ Violation Example

```java
// Zero tests shipped — "test later" = never tested
@Service
public class DiscountEngine {
    public Money calculateDiscount(Order order, String promoCode) {
        if (order.total().compareTo(HUNDRED) < 0) return Money.ZERO;
        var promo = promoRepo.findActive(promoCode)
            .orElseThrow(() -> new InvalidPromoException(promoCode));
        if (!promo.isValidFor(order)) return Money.ZERO;
        return promo.discountRate().apply(order.total());
    }
}
```

### ✅ Compliant Example

```java
// Tests generated alongside the implementation
@ExtendWith(MockitoExtension.class)
class DiscountEngineTest {

    @Mock PromoRepository promoRepo;
    @InjectMocks DiscountEngine engine;

    // Happy path
    @Test
    void appliesDiscount_whenOrderMeetsThreshold_andPromoIsValid() {
        var order = orderWithTotal(new Money("150"));
        when(promoRepo.findActive("SAVE10")).thenReturn(Optional.of(validPromo("SAVE10", 0.10)));

        var result = engine.calculateDiscount(order, "SAVE10");

        assertEquals(new Money("15.00"), result);
    }

    // Error path
    @Test
    void throwsInvalidPromo_whenPromoCodeNotFound() {
        var order = orderWithTotal(new Money("150"));
        when(promoRepo.findActive("GHOST")).thenReturn(Optional.empty());

        assertThrows(InvalidPromoException.class,
            () -> engine.calculateDiscount(order, "GHOST"));
    }

    // Edge case: order below threshold
    @Test
    void returnsZeroDiscount_whenOrderBelowThreshold() {
        var order = orderWithTotal(new Money("50"));

        var result = engine.calculateDiscount(order, "SAVE10");

        assertEquals(Money.ZERO, result);
        verifyNoInteractions(promoRepo);
    }
}
```

### Enforcement Strategy

- **Build tool**: Jacoco / Istanbul minimum branch coverage threshold (e.g., 80% for service module). Build fails if below threshold.
- **ArchUnit test**: Assert that every `@Service` class has a corresponding `*Test` class in the test source root.
- **CI gate**: Require at least one `@Test` annotated method per public method in non-trivial classes.
- **Code review checklist**: For every new service method, verify test file has at least 3 test methods (happy + error + edge).

---

## C4: Explain Non-Obvious Decisions

### Definition

Any design choice, algorithm selection, or workaround whose rationale is not immediately obvious from the code structure
must be explained with a "why" comment. The comment must describe **the problem that motivated the decision**,
not restate what the code already expresses. Acceptable forms: a `// WHY:` inline comment for local decisions,
or an Architecture Decision Record (ADR) for cross-cutting architectural choices.

### Applicable Scenarios

| Applies | May Skip |
|---------|----------|
| Unconventional algorithm choices (e.g., why use Quickselect instead of sorting) | Standard framework patterns (e.g., Spring `@Transactional` usage) |
| Workarounds for external library bugs | Self-documenting code where the API and naming make intent obvious |
| Intentionally non-obvious performance optimizations | |
| Business rule implementation where the rule seems counterintuitive | |
| ADR: architecture pattern selection, database choice, messaging topology | |

### ❌ Violation Example

```java
public List<Order> rankOrders(List<Order> orders) {
    // no explanation: why Quickselect? why this threshold? future maintainer is lost
    if (orders.size() > 10000) {
        return quickselect(orders, 100);  // magic number, obscure algorithm
    }
    return orders.stream()
        .sorted(Comparator.comparing(Order::total).reversed())
        .limit(100)
        .toList();
}
```

### ✅ Compliant Example

```java
/**
 * Ranks the top 100 orders by total value.
 *
 * WHY Quickselect for >10k orders: full sort is O(n log n) and allocates
 * intermediate collections. Quickselect gives O(n) average for top-K
 * with minimal GC pressure. Threshold of 10k was determined by JMH
 * benchmark on production-shaped data (2025-03-14, see ADR-014).
 * For smaller batches, stream sort is simpler and fast enough.
 */
public List<Order> rankTopOrders(List<Order> orders) {
    if (orders.size() > LARGE_BATCH_THRESHOLD) {
        return quickselectTopK(orders, TOP_K_COUNT);
    }
    return orders.stream()
        .sorted(Comparator.comparing(Order::total).reversed())
        .limit(TOP_K_COUNT)
        .toList();
}

private static final int LARGE_BATCH_THRESHOLD = 10_000;
private static final int TOP_K_COUNT = 100;
```

### Enforcement Strategy

- **Code review checklist**: For every method containing `//` or `/* */` comments, ensure at least one explains *why*, not *what*.
- **ADR directory check**: CI script verifies `docs/adr/` directory exists and contains records dated after project inception.
- **Linter custom rule**: Flag comments matching pattern `// (set|get|check|validate|compute|call|invoke)` as likely "what" comments needing upgrade to "why".

---

## C5: No Simplified "Demo" Code

### Definition

Generated code must assume a production context by default. This means no hardcoded credentials, no in-memory databases
masquerading as real persistence, no `main()` functions that skip error handling, no `Thread.sleep()` as a retry mechanism,
and no comment placeholders like `// TODO: implement error handling`. Every generated artifact must be deployable
to a production-like environment with only external configuration changes (see C12). Code that "looks like it works"
but crumbles under real traffic, concurrency, or failure is not acceptable.

### Applicable Scenarios

| Applies | May Skip |
|---------|----------|
| All code generation by default | Prototype/MVP context explicitly declared by user |
| Service, controller, repository codebases | Spike solution that will be thrown away (user must explicitly state this) |
| API definitions | |
| Infrastructure-as-code (Terraform, Pulumi) | |

### ❌ Violation Example

```python
# demo-quality: hardcoded values, no retry, no circuit breaker, no observability
import sqlite3
import requests

DB = sqlite3.connect(":memory:")   # in-memory — all data lost on restart
API_KEY = "sk-demo-key-12345"      # hardcoded secret in source code

def call_payment_service(order):
    resp = requests.post("http://localhost:8080/pay", json=order)
    if resp.status_code != 200:
        print("Payment failed, but proceeding anyway")  # demo attitude
    return resp.json()

# TODO: add proper error handling later
```

### ✅ Compliant Example

```python
import os
import structlog
from tenacity import retry, stop_after_attempt, wait_exponential

logger = structlog.get_logger()

PAYMENT_SERVICE_URL = os.environ["PAYMENT_SERVICE_URL"]
PAYMENT_API_KEY = os.environ["PAYMENT_API_KEY"]
MAX_RETRIES = 3

@retry(
    stop=stop_after_attempt(MAX_RETRIES),
    wait=wait_exponential(multiplier=1, min=1, max=10),
    reraise=True,
)
def call_payment_service(order: dict) -> dict:
    resp = requests.post(
        PAYMENT_SERVICE_URL,
        json=order,
        headers={"Authorization": f"Bearer {PAYMENT_API_KEY}"},
        timeout=(3.0, 10.0),  # connect timeout, read timeout
    )
    resp.raise_for_status()  # non-2xx becomes exception — no silent failures
    logger.info("payment_success", order_id=order["id"], amount=order["total"])
    return resp.json()
```

### Enforcement Strategy

- **Static analysis**: Scan for hardcoded URLs (`localhost`), placeholder secrets (`demo-key`, `test-token`), and `://memory:` database connection strings.
- **Build-time check**: Assert no `TODO` comments referencing error handling or security in merged PRs (use Danger.js or custom CI script).
- **Code review checklist**: For every generated file, ask: "If deployed to production right now, what would break?" Flag any answer that isn't "nothing, given correct config."

---

## C6: Security by Default

### Definition

Generated code must incorporate security controls from the first line, not retrofitted later. At minimum, this means:
parameterized queries for all database access (no string concatenation for SQL), output encoding/escaping for all
user-supplied content, no secrets in logs or source control, validated authentication on every protected endpoint,
and proper CORS configuration rather than wildcard origins. The OWASP Top 10 serves as the baseline threat model.

### Applicable Scenarios

| Applies | May Skip |
|---------|----------|
| All code touching databases, user input, or authentication | Internal admin tools used exclusively within a VPN with no external access |
| All API endpoints | Read-only public data with no user-specific content |
| All file upload handlers | |
| All serialization/deserialization of external data | |

### ❌ Violation Example

```java
@GetMapping("/orders")
public List<Order> listOrders(@RequestParam String userId) {
    // SQL injection vector: userId concatenated directly into query
    String sql = "SELECT * FROM orders WHERE user_id = " + userId;
    return jdbcTemplate.query(sql, orderRowMapper);
}

@GetMapping("/users/{id}")
public User getUser(@PathVariable Long id) {
    // JPA entity leaked — returns hashedPassword, apiToken, internal flags
    return userRepo.findById(id).orElseThrow();
}
```

### ✅ Compliant Example

```java
@GetMapping("/orders")
public List<OrderDto> listOrders(@RequestParam @Positive Long userId) {
    // Spring Data JPA — parameterized query by construction, no SQL injection
    return orderRepo.findByUserId(userId).stream()
        .map(OrderDto::from)
        .toList();
}

@GetMapping("/users/{id}")
public UserDto getUser(@PathVariable @Positive Long id) {
    // DTO explicitly excludes sensitive fields (hashedPassword, apiToken, etc.)
    return userRepo.findDtoById(id)
        .orElseThrow(() -> new UserNotFoundException(id));
}

// CORS configuration — explicit origins, never wildcard in production
@Bean
public CorsFilter corsFilter(ApplicationConfig config) {
    var source = new UrlBasedCorsConfigurationSource();
    var cors = new CorsConfiguration();
    cors.setAllowedOrigins(config.allowedOrigins());  // explicit list, not "*"
    cors.setAllowedMethods(List.of("GET", "POST", "PUT"));
    cors.setAllowCredentials(true);
    source.registerCorsConfiguration("/api/**", cors);
    return new CorsFilter(source);
}
```

### Enforcement Strategy

- **SAST tool**: Run SpotBugs with `FindSecBugs` plugin, Semgrep with OWASP ruleset, or SonarQube security rules in CI. Build fails on Critical/Blocker security issues.
- **Secret scanning**: `git-secrets` or `truffleHog` pre-commit hook to prevent API keys, tokens, or credentials from entering the repo.
- **ArchUnit test**: Assert no `@RestController` method returns `@Entity`-annotated classes directly.
- **Dependency audit**: `owasp-dependency-check` Maven/Gradle plugin in CI to detect CVEs in third-party libraries.

---

## C7: Resource Cleanup

### Definition

Every acquired resource — database connections, file handles, network sockets, thread pools, locks — must be released
deterministically, regardless of whether the operation succeeded or failed. Use language-native mechanisms:
`try-with-resources` (Java), `defer` (Go), context managers / `with` statements (Python), RAII (C++/Rust).
Manual `close()` calls without a `finally` block or equivalent guarantee are insufficient. Leaked resources accumulate
silently and cause production outages under load (connection pool exhaustion, file descriptor limits, out-of-memory).

### Applicable Scenarios

| Applies | May Skip |
|---------|----------|
| All I/O operations (file, network, DB) | Short-lived CLI tools where process exit guarantees OS-level cleanup |
| All lock acquisition (distributed and local) | |
| All thread pool / executor service usage | |
| All external resource handles (JDBC, HTTP clients, Kafka producers/consumers) | |

### ❌ Violation Example

```go
func exportReport(orderID string) error {
    file, err := os.Create("/exports/" + orderID + ".csv")
    if err != nil {
        return fmt.Errorf("create file: %w", err)
    }
    // file is never closed — resource leak.
    // If writeCSV panics, the fd is leaked permanently.
    // Under load, process hits ulimit and crashes.

    data, err := loadOrderData(orderID)
    if err != nil {
        return err  // early return — file handle leaked
    }
    return writeCSV(file, data)
}
```

### ✅ Compliant Example

```go
func exportReport(orderID string) (err error) {
    file, err := os.Create("/exports/" + orderID + ".csv")
    if err != nil {
        return fmt.Errorf("create file: %w", err)
    }
    defer func() {
        if closeErr := file.Close(); closeErr != nil && err == nil {
            err = fmt.Errorf("close file: %w", closeErr)
        }
    }()

    data, err := loadOrderData(orderID)
    if err != nil {
        return fmt.Errorf("load order data: %w", err)
    }
    return writeCSV(file, data)
}
```

### Enforcement Strategy

- **Static analysis**: SpotBugs rule `OS_OPEN_STREAM`, `ODR_OPEN_DATABASE_RESOURCE`; Go `staticcheck` SA4000 (pointers to enclosing loop variables); Python `pylint` W0702 (no explicit close).
- **CI test**: Run service under load for 5 minutes; assert file descriptor count and DB connection count remain stable (no monotonic increase).
- **Code review checklist**: Every `new FileInputStream`, `sql.Open`, `HttpClient.newHttpClient()` must have a corresponding `close()` reachable from all exit paths (normal return, error return, panic).

---

## C8: Method Length ≤ 60 lines

### Definition

No single method (excluding its Javadoc/signature) shall exceed 60 lines of executable code. This is not a cosmetic rule —
long methods mix multiple levels of abstraction, making it hard to identify which section failed during debugging,
impossible to unit-test individual sub-operations, and resistant to reuse. A method longer than 60 lines almost
certainly violates the Single Responsibility Principle at the method level.

Length signals:
- **≤ 20 lines**: excellent, reads like a story
- **21-40 lines**: acceptable if coherent and single-purpose
- **41-60 lines**: borderline — verify it cannot be decomposed further; if it can, extract
- **> 60 lines**: violation — extract sub-operations into private methods with descriptive names

### Applicable Scenarios

| Applies | May Skip |
|---------|----------|
| All production methods across all languages | Switch-case exhaustive pattern matching over sealed types (~20-30 branches, each 1-2 lines) — acceptable if each branch delegates |
| Service, controller, repository, utility code | Generated code (MapStruct mappers, Protobuf stubs) |
| Test methods (shorter is still better) | |

### ❌ Violation Example

```java
// 78 lines, mixes validation, pricing, inventory, payment, notification — four abstraction levels
public OrderResult checkout(CheckoutRequest req) {
    if (req.cart() == null || req.cart().isEmpty()) {           // line 1
        throw new InvalidCartException("Cart is empty");       // line 2
    }                                                           // line 3
    for (var item : req.cart()) {                               // line 4
        if (item.quantity() <= 0) {                             // line 5
            throw new InvalidCartException("Invalid qty");      // line 6
        }                                                       // line 7
    }                                                           // line 8
    // ... 70 more lines of mixed pricing, payment, inventory, notification logic
    return new OrderResult(order.id(), total, transactionId);   // line 78
}
```

### ✅ Compliant Example

```java
// 7 lines — reads at exactly one level of abstraction
public OrderResult checkout(CheckoutRequest req) {
    validateCart(req);
    var pricing = calculatePricing(req);
    var payment = capturePayment(req, pricing);
    var order = createOrder(req, pricing, payment);
    notifyCustomer(order);
    return buildResult(order, payment);
}

// Each extracted method is ~5-15 lines and independently testable
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

### Enforcement Strategy

- **Static analysis**: Checkstyle rule `MethodLength` (`max=60`); PMD rule `ExcessiveMethodLength`; ESLint `max-lines-per-function`.
- **CI gate**: Build fails if any method exceeds 60 executable lines (excluding blank lines and comments).
- **Code review checklist**: For every method exceeding 40 lines, ask: "Can any contiguous block of this method be extracted, given a name, and tested independently?"

---

## C9: Atomicity Guarantee

### Definition

Any operation that mutates state across multiple steps must either complete all steps successfully or leave the system
exactly as it was before the operation began. Partial completion is corruption — it produces a state that no valid
business flow could have produced. The atomicity boundary depends on the architecture:
- **Single database**: use ACID transactions with rollback on any failure.
- **Distributed systems**: use Saga orchestration with compensating actions, or the Outbox pattern where the DB
  is the single source of truth and downstream systems achieve eventual consistency.

### Applicable Scenarios

| Applies | May Skip |
|---------|----------|
| All multi-step state mutations | Read-only operations (naturally atomic) |
| All database write operations spanning multiple tables | Single-table single-row INSERT/UPDATE within one transaction |
| All distributed workflows (order → payment → inventory) | |
| All file/config write operations | |

### ❌ Violation Example

```java
// Non-atomic: three independent writes with no transaction boundary.
// If step 2 fails after step 1 succeeded, DB is consistent but cache and
// search index now hold different versions of truth. Manual reconciliation required.
public void updateUser(User user) {
    userRepo.save(user);                             // step 1: DB write — succeeds
    cache.set("user:" + user.id(), user);            // step 2: cache update — fails (network blip)
    searchIndex.index(user);                         // step 3: ES reindex — also fails
    // Result: DB correct, cache stale, search missing user. Three realities.
}
```

### ✅ Compliant Example

```java
// DB is the single source of truth. Cache and search are eventually consistent
// via the Outbox pattern — all-or-nothing at the DB boundary.
@Transactional
public void updateUser(UpdateUserCommand cmd) {
    var user = userRepo.findById(cmd.userId())
        .orElseThrow(() -> new UserNotFoundException(cmd.userId()));

    user.updateProfile(cmd.name(), cmd.email());     // domain logic
    userRepo.save(user);

    // Outbox event: persisted atomically within the same transaction.
    // If the DB commit succeeds, the event exists. If it fails, nothing exists.
    // Downstream consumers (cache warmer, search indexer) pick up via CDC or polling.
    outboxRepo.save(new OutboxEvent(
        "UserProfileUpdated",
        new UserProfileUpdatedPayload(user.id(), user.name(), user.email())
    ));
}
// After commit: cache and search are stale for at most the polling interval.
// This is eventual consistency — correct, just slightly delayed.
// No partial state. No manual reconciliation. No three realities.
```

### Enforcement Strategy

- **ArchUnit test**: Assert every `@Transactional` method does NOT contain external HTTP calls, message sends without outbox, or file writes.
- **Integration test**: Each multi-step mutation test must include: (a) full success verification, (b) forced mid-operation failure followed by assertion that all state matches pre-operation baseline.
- **Code review checklist**: Identify every method that writes to more than one storage system. For each, verify an atomicity strategy exists (transaction, Saga + compensation, or Outbox).

---

## C10: Idempotency

### Definition

A state-changing operation, when applied multiple times with the same inputs, must produce the same final system state
as when applied exactly once. This is critical for distributed systems where network retries, message redelivery,
or user double-clicks can cause duplicate execution. For operations that are NOT naturally idempotent
(e.g., payment charges, email sends, POST-creation), the system must accept an **Idempotency-Key** header from
the caller and deduplicate based on it, returning the original result for repeat keys.

### Applicable Scenarios

| Applies | May Skip |
|---------|----------|
| All POST / PATCH endpoints that create or modify resources | GET / HEAD / OPTIONS (naturally idempotent) |
| All payment / financial transaction endpoints | PUT (full replace — naturally idempotent) |
| All message queue consumers (at-least-once delivery) | DELETE (naturally idempotent after first call) |
| All external API call retry logic | Internal-only APIs where the sole caller guarantees exactly-once delivery |

### ❌ Violation Example

```java
// No idempotency protection. Network hiccup → client retries → double charge.
@PostMapping("/payments")
public Payment create(@RequestBody PaymentRequest req) {
    return paymentService.charge(req);     // retry = second charge = customer double-billed
}
```

### ✅ Compliant Example

```java
@PostMapping("/payments")
public ResponseEntity<?> create(
    @RequestHeader("Idempotency-Key") @NotBlank String idempotencyKey,
    @Valid @RequestBody PaymentRequest req
) {
    return idempotencyService.execute(idempotencyKey, req, request -> {
        var payment = paymentGateway.charge(request);
        return ResponseEntity.created(URI.create("/payments/" + payment.id()))
            .body(PaymentDto.from(payment));
    });
}

// IdempotencyService internals (conceptual):
// 1. INSERT idempotency_key INTO idempotency_keys (key, status=PROCESSING)
// 2. If unique constraint violation → key already exists:
//    a. If status=COMPLETED → return stored result
//    b. If status=PROCESSING → return 409 Conflict (in-flight)
// 3. Execute request function
// 4. UPDATE status=COMPLETED, store result
// 5. Return fresh result
// If the server crashes after step 3 and before step 4,
// the client retries with the same key → gets the stored result.
```

### Enforcement Strategy

- **ArchUnit test**: Assert every `@PostMapping` method in `@RestController` classes either (a) accepts an `Idempotency-Key` header, or (b) delegates to an `IdempotencyService`.
- **Integration test**: For every POST endpoint: send identical request twice with the same idempotency key. Assert second call returns the SAME response body and status as the first, and the resource is created exactly once.
- **Code review checklist**: Every state-changing API endpoint must declare its idempotency strategy (natural, key-based, or condition-based with ETag/version).

---

## C11: Observability Built-in

### Definition

Every service must emit structured telemetry from its first deployment: **metrics** (request count, latency, error rate,
business KPIs), **structured logs** (JSON with trace-id, span-id, and key business identifiers), and **distributed traces**
(propagating trace context across service boundaries). Observability is not an ops-team afterthought — it is a
first-class feature of the code. Without it, production incidents are diagnosed by guesswork, and every outage
lasts 3x longer than necessary.

### Applicable Scenarios

| Applies | May Skip |
|---------|----------|
| All production services and APIs | MVP/prototype context explicitly declared by user |
| All external call sites (metrics for latency, error rate) | CLI developer tools used only locally |
| All state-changing operations (audit trail via logs) | |
| All async workers / message consumers | |

### ❌ Violation Example

```java
@RestController
public class OrderController {
    private final OrderService orderService;

    @PostMapping("/orders")
    public Order create(@RequestBody CreateOrderRequest req) {
        // No metrics. No structured logging. No trace propagation.
        // If this endpoint becomes slow — zero data to diagnose.
        // Which part is slow? Validation? DB? External call? No one knows.
        return orderService.create(req);
    }
}
```

### ✅ Compliant Example

```java
@RestController
public class OrderController {
    private final OrderService orderService;
    private final MeterRegistry meterRegistry;
    private final Logger log = LoggerFactory.getLogger(OrderController.class);

    private final Counter ordersCreated;
    private final Timer orderCreationLatency;

    public OrderController(OrderService orderService, MeterRegistry meterRegistry) {
        this.orderService = orderService;
        this.meterRegistry = meterRegistry;
        this.ordersCreated = Counter.builder("orders.created.total")
            .description("Total orders created")
            .register(meterRegistry);
        this.orderCreationLatency = Timer.builder("orders.creation.latency")
            .description("Order creation latency")
            .publishPercentiles(0.5, 0.95, 0.99)
            .register(meterRegistry);
    }

    @PostMapping("/orders")
    public OrderDto create(@Valid @RequestBody CreateOrderRequest req) {
        Timer.Sample sample = Timer.start(meterRegistry);

        try {
            var order = orderService.create(req);
            ordersCreated.increment();

            // Structured log with business identifiers — queryable in log aggregator
            log.info("Order created: orderId={}, userId={}, amount={}, itemCount={}",
                order.id(), req.userId(), order.total(), req.items().size());

            return OrderDto.from(order);
        } catch (Exception e) {
            log.error("Order creation failed: userId={}, error={}",
                req.userId(), e.getMessage(), e);
            throw e;
        } finally {
            sample.stop(orderCreationLatency);
        }
    }
}
```

### Enforcement Strategy

- **Micrometer/OpenTelemetry check**: CI asserts every module has a dependency on `micrometer-registry-prometheus` (Java), `opentelemetry-api` (Go), or equivalent.
- **Log format check**: CI scans log output in integration tests; asserts JSON-structured format with at minimum `@timestamp`, `level`, `message`, and `traceId` fields.
- **Code review checklist**: Every new `@RestController` must expose at minimum one Counter (total requests) and one Timer (latency). Every external HTTP call must create a Timer.

---

## C12: Configuration Externalization

### Definition

Every value that changes between environments (dev, staging, production) or varies by deployment context must be
stored outside the application binary: environment variables, configuration files, ConfigMaps/Secrets (Kubernetes),
or external config servers (Spring Cloud Config, Consul). Hardcoded URLs, credentials, feature flags, timeouts,
batch sizes, and thresholds within source code are prohibited. This decouples deployment from build and eliminates
"worked in dev, broke in prod" surprises.

### Applicable Scenarios

| Applies | May Skip |
|---------|----------|
| Database connection strings and credentials | Pure algorithmic constants (e.g., `Math.PI`, `UTF_8` charset) |
| External service URLs and API keys | Domain invariants that are never environment-specific |
| Feature flags and rollout percentages | |
| Timeout, retry, and pool-size values | |
| Log levels and metric export endpoints | |

### ❌ Violation Example

```python
# Hardcoded — requires code change and redeployment to switch environments
DATABASE_URL = "jdbc:postgresql://db-prod.internal:5432/orders"
REDIS_HOST = "redis-prod.internal"
REDIS_PORT = 6379
STRIPE_API_KEY = "sk_live_xxxxxxxxxxxxx"  # secret in source code — nightmare
REQUEST_TIMEOUT = 30  # seconds — no way to tune per environment

class PaymentService:
    def charge(self, request):
        client = HttpClient(base_url="https://api.stripe.com/v1")
        return client.post("/charges", request, timeout=REQUEST_TIMEOUT)
```

### ✅ Compliant Example

```python
import os
from pydantic_settings import BaseSettings

class AppSettings(BaseSettings):
    # 12-Factor App: configuration via environment variables with sensible defaults
    database_url: str = os.environ["DATABASE_URL"]
    redis_url: str = os.environ["REDIS_URL"]
    stripe_api_key: str = os.environ["STRIPE_API_KEY"]  # never in source code

    # Tuned per environment with a dev-safe default
    request_timeout_seconds: int = int(os.getenv("REQUEST_TIMEOUT_SECONDS", "30"))
    max_retry_attempts: int = int(os.getenv("MAX_RETRY_ATTEMPTS", "3"))

    # Feature flags externalized — can toggle without deployment
    enable_new_pricing_engine: bool = os.getenv("FEATURE_NEW_PRICING", "false").lower() == "true"

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}

settings = AppSettings()

class PaymentService:
    def __init__(self, config: AppSettings):
        self.client = HttpClient(
            base_url="https://api.stripe.com/v1",
            default_headers={"Authorization": f"Bearer {config.stripe_api_key}"}
        )
        self.timeout = config.request_timeout_seconds

    def charge(self, request):
        return self.client.post("/charges", request, timeout=self.timeout)
```

### Enforcement Strategy

- **Static analysis**: Semgrep rule to detect hardcoded URLs (`http://` or `https://` as string literals), IP addresses, and patterns matching API key formats.
- **CI check**: Diff between env-specific config files must be zero for structures — only values differ. A config value appearing in 2+ environments with the same value is suspicious (should it be a constant?).
- **Code review checklist**: For every string literal in non-test source code, ask: "Does this value change between dev, staging, and production?" If yes, externalize.

---

## C13: Backward Compatibility

### Definition

Any change to a public API contract — adding/removing fields, changing field types, altering error response structure,
modifying endpoint paths — must not break existing consumers. Use non-breaking evolution strategies:
**additive-only changes** (new optional fields, new endpoints), **versioning** (URL path, header, or content negotiation),
and **expand-contract migrations** (deploy new version alongside old → migrate consumers → deprecate old version →
remove old version). Breaking changes are permitted only with a clearly communicated deprecation window and migration guide.

### Applicable Scenarios

| Applies | May Skip |
|---------|----------|
| All public-facing APIs (external consumers) | Greenfield APIs with zero existing consumers |
| All APIs consumed by other internal teams | Internal APIs owned by a single team where consumer and producer deploy together |
| All shared event schemas (Kafka, message queues) | |
| All shared library public methods | |

### ❌ Violation Example

```java
// v1: returns simple DTO
@GetMapping("/api/v1/orders/{id}")
public OrderDtoV1 getOrder(@PathVariable Long id) {
    return orderService.getV1(id);
}

// "v1" endpoint modified in-place — all existing consumers break on deploy
@GetMapping("/api/v1/orders/{id}")
public OrderDtoV2 getOrder(@PathVariable Long id) {
    return orderService.getV2(id);  // new field "fulfillmentChannel" added,
                                    // old field "total" renamed to "amount"
                                    // → all mobile clients crash on deserialization
}
```

### ✅ Compliant Example

```java
// v1: preserved unchanged — existing consumers continue working
@GetMapping("/api/v1/orders/{id}")
public OrderDtoV1 getOrderV1(@PathVariable Long id) {
    return orderService.getV1(id);
}

// v2: new endpoint, additive changes only — opt-in migration
@GetMapping("/api/v2/orders/{id}")
public OrderDtoV2 getOrderV2(@PathVariable Long id) {
    return orderService.getV2(id);
}

// v1 DTO — frozen, never modified
public record OrderDtoV1(Long id, String status, Money total, Instant createdAt) {}

// v2 DTO — additive: new optional field fulfillmentChannel, field total preserved
public record OrderDtoV2(
    Long id, String status, Money total, Instant createdAt,
    @Nullable String fulfillmentChannel  // new field, null for migrated orders — no break
) {}

// Deprecation header on v1 responses
@GetMapping("/api/v1/orders/{id}")
public ResponseEntity<OrderDtoV1> getOrderV1(@PathVariable Long id) {
    return ResponseEntity.ok()
        .header("Deprecation", "true")
        .header("Sunset", "Sat, 31 Dec 2026 23:59:59 GMT")
        .header("Link", "</api/v2/orders/" + id + ">; rel=\"successor-version\"")
        .body(orderService.getV1(id));
}
```

### Enforcement Strategy

- **Contract testing**: Pact or Spring Cloud Contract tests for every API consumer. CI verifies that provider changes never break registered consumer contracts.
- **OpenAPI diff**: CI step runs `openapi-diff` between current and proposed spec. Flag breaking changes (removed fields, changed types) with required approval.
- **Code review checklist**: For every API change, ask: "Will any existing consumer (even internal) break if I deploy this now?" If yes, the change requires versioning or expand-contract.

---

## C14: Documentation Sync

### Definition

Every significant design decision or architectural change must be captured in an Architecture Decision Record (ADR)
that is checked into the repository alongside the code it describes. An ADR documents the **context** (what problem
we faced), the **decision** (what we chose and why), the **considered alternatives** (what we rejected and why),
and the **consequences** (what trade-offs we accept). ADRs are immutable after merge — superseded decisions
get a new ADR that references the old one with status "superseded."

### Applicable Scenarios

| Applies | May Skip |
|---------|----------|
| Framework/library selection | Trivial implementation details with no architectural consequence |
| Architecture pattern adoption (CQRS, Event Sourcing, Saga) | |
| Database/technology choices | |
| API versioning strategy decisions | |
| Cross-cutting concern implementations (auth, logging, monitoring) | |

### ❌ Violation Example

```java
// Six months later, a new team member encounters this code. Why Event Sourcing?
// Why not plain CRUD? No ADR. The original team has moved on.
// The decision rationale exists only in Slack threads and meeting notes — both gone.
@Service
public class OrderEventSourcingService {
    private final EventStore eventStore;

    public void placeOrder(PlaceOrderCommand cmd) {
        var events = orderAggregate.handle(cmd);
        eventStore.append("order-" + cmd.orderId(), events, EXPECTED_VERSION_NONE);
    }
    // No ADR explains why Event Sourcing was chosen over simple CRUD with audit table.
    // Future team cannot evaluate whether to keep or replace this pattern.
}
```

### ✅ Compliant Example

```java
// Code references the ADR explicitly
/**
 * Implements order lifecycle via Event Sourcing.
 *
 * @see <a href="docs/adr/0014-order-event-sourcing.md">ADR-0014: Event Sourcing for Order Lifecycle</a>
 */
@Service
public class OrderEventSourcingService {
    // ...
}
```

```markdown
<!-- docs/adr/0014-order-event-sourcing.md -->

# ADR-0014: Event Sourcing for Order Lifecycle

**Status**: Accepted
**Date**: 2025-11-18
**Deciders**: @alice, @bob, @charlie

## Context
The order domain requires a complete, immutable audit trail for compliance (SOC2 §CC7.2).
Every state transition (CREATED → CONFIRMED → PAID → SHIPPED → DELIVERED → CANCELLED)
must be reconstructible at any point in time.

## Decision
Implement Event Sourcing for the Order aggregate. Each state transition is a domain event
appended to an append-only event store. The current state is a projection of the event stream.

## Considered Alternatives
1. **Audit table + CRUD state table**: Simpler, but two sources of truth diverge under race conditions.
   Rejected: no single source of truth for compliance audits.
2. **CDC from CRUD state table (Debezium)**: Captures row-level changes, not domain intent.
   Rejected: "row updated" is not "OrderPaid" — semantic gap is too large.

## Consequences
- **Positive**: Immutable audit trail by construction. Full temporal queries (state at any past time).
- **Negative**: Eventual consistency for projections. CQRS read models may lag.
- **Negative**: Team must learn Event Sourcing patterns (snapshotting, event versioning).
```

### Enforcement Strategy

- **CI directory check**: `docs/adr/` must exist and contain at minimum `0001-record-architecture-decisions.md` (the initial ADR establishing the practice).
- **PR template**: Every pull request with label `architecture-change` must include a link to the corresponding ADR in its description, or the PR cannot be merged.
- **ADR lint**: CI checks that every ADR contains mandatory sections: Status, Date, Deciders, Context, Decision, Consequences.

---

## C15: Dependency Minimalism

### Definition

Every external dependency (library, framework, SDK) added to the project must justify its inclusion against
the total cost of ownership: version conflicts, security vulnerability surface, transitive dependency bloat,
build time increase, and onboarding friction. Prefer standard library APIs over third-party libraries when
the stdlib solution covers at least 80% of the need. "Left-pad" style micro-dependencies (a library that
provides a single trivial function) are strictly prohibited — inline the 5-line implementation instead.

### Applicable Scenarios

| Applies | May Skip |
|---------|----------|
| Every new dependency addition | Frameworks already established as project standards (Spring Boot, Express, FastAPI) |
| Utility library selections | Language standard libraries (stdlib, JDK, Python standard library) |
| Logging, JSON parsing, HTTP client decisions | |
| Test framework/library choices (prefer built-in over additional) | |

### ❌ Violation Example

```go
// 15 external dependencies to do what the standard library already provides.
// Each dependency is a future CVE, version conflict, and onboarding tax.
import (
    "github.com/someone/leftpad"       // 5-line function → 1 dependency
    "github.com/another/isempty"       // 2-line function → 1 dependency
    "github.com/third/retry"           // stdlib + net/http can do this
    "github.com/fourth/httpclient"     // stdlib net/http already exists
)

func processOrder(id string) (Order, error) {
    padded := leftpad.Pad(id, 10)              // why not fmt.Sprintf("%010s", id)?
    if isempty.IsEmpty(padded) { return ... }  // why not len(padded) == 0?
    // ...
}
```

### ✅ Compliant Example

```go
import (
    "fmt"
    "net/http"
    "time"
    // Zero external utility dependencies. stdlib covers all the needs.
)

func processOrder(id string) (Order, error) {
    padded := fmt.Sprintf("%010s", id)        // stdlib — no dependency
    if len(padded) == 0 {
        return Order{}, fmt.Errorf("empty order id")
    }

    client := &http.Client{
        Timeout: 10 * time.Second,            // stdlib — no retry library
    }
    // ...
}
```

### Dependency Justification Checklist (use before adding any dependency):

| Question | Must Answer |
|----------|-------------|
| Does the stdlib solve 80%+ of this? | Yes → use stdlib. No → continue. |
| Is this a 1-file implementation? | Yes → inline it. No → continue. |
| Who maintains this library? | Single person, last commit 2+ years ago → reject. Active org → continue. |
| What is the transitive dependency count? | > 10 transitive deps → reconsider. |
| Is there a lighter alternative? | Evaluate alternatives by maintainer health, not just popularity. |

### Enforcement Strategy

- **Dependency audit CI**: `go mod graph` / `mvn dependency:tree` / `pipdeptree` — assert no dependency pulls in > 50 transitive dependencies without explicit approval.
- **Bundle size check**: Webpack/Rollup bundle analyzer in CI; PR fails if bundle size increases by more than 5% without justification.
- **Pre-commit hook**: For Go projects, `golangci-lint` with `depguard` rule to block known over-engineered utility packages.
- **Code review checklist**: For every new `import` of an external library not already in the project, verify the PR description includes answers to the Dependency Justification Checklist.

---

## PCTF Framework (Persona-Context-Task-Format)

Use this structured prompt engineering framework to produce consistent, high-quality generation outputs:

| Element | Question to Answer | Example |
|---------|--------------------|---------|
| **P**ersona | Who is generating? | "Expert Java architect with 15 years of fintech experience" |
| **C**ontext | What constraints and environment? | "Production banking system, Spring Boot 3.2, PostgreSQL, must pass SOC2 audit" |
| **T**ask | What exactly needs to be done? | "Implement idempotent payment endpoint with Saga orchestration" |
| **F**ormat | What is the output structure? | "Return: Controller → Service → Repository with tests" |

### When to Use PCTF

| Task Complexity | PCTF Required? |
|-----------------|----------------|
| Simple bug fix, one-line change | No — overkill |
| Adding a single CRUD endpoint to an existing pattern | Light (P + C only) |
| New feature with multiple layers | Full PCTF |
| Architectural decision, greenfield service | Full PCTF + ADR (C14) |
| Security-sensitive implementation | Full PCTF + Security review (C6) |

The PCTF framework ensures that the generated code matches both the technical environment and the organizational
expectations, preventing the "correct code, wrong context" problem where an implementation is technically valid
but inappropriate for the deployment environment.

---
</ Rewritten>
</parameter>
</invoke>
</tool_calls>