# Before/After Transformation Examples

Every example below demonstrates the transformation from "working code" to "production-ready expert code" by applying Code Excellence constraints (C1-C15).

---

## E1: CRUD Controller — Input Validation + Idempotency

### ❌ Before
```java
@RestController
@RequestMapping("/api/payments")
public class PaymentController {

    private final PaymentService paymentService;

    public PaymentController(PaymentService paymentService) {
        this.paymentService = paymentService;
    }

    @PostMapping
    public Payment create(@RequestBody CreatePaymentRequest request) {
        return paymentService.charge(request);
    }
}
```

```java
public record CreatePaymentRequest(
    Long orderId,
    String cardNumber,
    BigDecimal amount,
    String currency
) {}
```

### Problem Analysis

No input validation at the boundary — an attacker can send `null` for every field, a negative `amount`, or a SQL injection payload in `cardNumber`. The POST endpoint has no idempotency protection: a network retry creates two charges for the same order. This is the #1 cause of double-billing incidents in payment systems.

### ✅ After
```java
@RestController
@RequestMapping("/api/v1/payments")
public class PaymentController {

    private final PaymentService paymentService;
    private final IdempotencyService idempotencyService;

    public PaymentController(PaymentService paymentService,
                             IdempotencyService idempotencyService) {
        this.paymentService = paymentService;
        this.idempotencyService = idempotencyService;
    }

    @PostMapping
    public ResponseEntity<Payment> create(
            @RequestHeader("Idempotency-Key") @NotBlank String idempotencyKey,
            @Valid @RequestBody CreatePaymentRequest request) {

        return idempotencyService.execute(idempotencyKey, request.orderId(),
            () -> ResponseEntity.status(HttpStatus.CREATED)
                .body(paymentService.charge(request)));
    }
}
```

```java
public record CreatePaymentRequest(
    @NotNull Long orderId,
    @NotBlank @Pattern(regexp = "\\d{13,19}") String cardNumber,
    @NotNull @Positive @Digits(integer = 12, fraction = 2) BigDecimal amount,
    @NotBlank @Size(min = 3, max = 3) String currency
) {}
```

```java
@Service
public class IdempotencyService {

    private final IdempotencyRecordRepository repository;

    public <T> T execute(String key, Long resourceId,
                         Supplier<T> action) {
        var existing = repository.findByKey(key);
        if (existing.isPresent()) {
            return existing.get().result();
        }
        var result = action.get();
        repository.save(new IdempotencyRecord(key, resourceId,
            Instant.now(), Duration.ofHours(24)));
        return result;
    }
}
```

### Expert Note

C1 (Input Validation at Boundary): every field is constrained with Jakarta Validation annotations — invalid data is rejected before it touches any service. C10 (Idempotency): the `Idempotency-Key` header guarantees at-most-once semantics; a retried request returns the cached result instead of charging the customer twice.

---

## E2: Error Handling — Silent Failure to Structured Observability

### ❌ Before
```java
public class OrderProcessor {

    private final PaymentGateway paymentGateway;
    private final InventoryClient inventoryClient;

    public void processOrder(Order order) {
        try {
            paymentGateway.charge(order);
        } catch (PaymentException e) {
            log.error("Payment failed");
        }

        try {
            inventoryClient.reserve(order.items());
        } catch (Exception ignored) {
        }

        order.setStatus(OrderStatus.CONFIRMED);
        orderRepository.save(order);
    }
}
```

### Problem Analysis

The catch block for payment failure logs a bare string — no order ID, no amount, no stack trace — making debugging impossible in production. The inventory reservation error is silently swallowed: the system ships goods that were never reserved, creating an unfixable stock discrepancy. The order is always marked `CONFIRMED` regardless of whether critical prerequisite steps actually succeeded.

### ✅ After
```java
@Slf4j
public class OrderProcessor {

    private final PaymentGateway paymentGateway;
    private final InventoryClient inventoryClient;
    private final MeterRegistry meterRegistry;

    private final Counter paymentFailures;
    private final Counter inventoryFailures;

    public OrderProcessor(PaymentGateway paymentGateway,
                          InventoryClient inventoryClient,
                          MeterRegistry meterRegistry) {
        this.paymentGateway = paymentGateway;
        this.inventoryClient = inventoryClient;
        this.meterRegistry = meterRegistry;
        this.paymentFailures = Counter.builder("order.payment.failures")
            .description("Count of payment charge failures")
            .register(meterRegistry);
        this.inventoryFailures = Counter.builder("order.inventory.failures")
            .description("Count of inventory reservation failures")
            .register(meterRegistry);
    }

    public void processOrder(Order order) {
        chargePayment(order);
        reserveInventory(order);
        order.setStatus(OrderStatus.CONFIRMED);
        orderRepository.save(order);
    }

    private void chargePayment(Order order) {
        try {
            paymentGateway.charge(order);
        } catch (PaymentException e) {
            paymentFailures.increment();
            log.error("Payment charge failed orderId={} amount={} currency={}",
                order.id(), order.total(), order.currency(), e);
            throw new OrderProcessingException("payment", order.id(), e);
        }
    }

    private void reserveInventory(Order order) {
        try {
            inventoryClient.reserve(order.items());
        } catch (InventoryException e) {
            inventoryFailures.increment();
            log.error("Inventory reservation failed orderId={} items={}",
                order.id(), order.items().size(), e);
            throw new OrderProcessingException("inventory", order.id(), e);
        }
    }
}
```

### Expert Note

C2 (No Silent Failures): every exception is either rethrown as a typed domain exception or handled with a deliberate recovery path — never silently swallowed. C11 (Observability Built-in): structured logging includes all correlation identifiers (`orderId`, `amount`) and full stack traces; Micrometer counters (`paymentFailures`, `inventoryFailures`) feed dashboards and alerting rules so operations teams detect anomalies before customers do.

---

## E3: Configuration — Hardcoded Values to Externalized Configuration

### ❌ Before
```java
@Component
public class SmsNotificationService {

    private static final String SMS_API_URL = "https://sms-api.internal.example.com/v2/send";
    private static final String API_KEY = "sk-prod-8a7b6c5d4e3f2a1b";
    private static final int MAX_RETRIES = 3;
    private static final int CONNECT_TIMEOUT_MS = 5000;

    public void send(String phone, String message) {
        var client = HttpClient.newBuilder()
            .connectTimeout(Duration.ofMillis(CONNECT_TIMEOUT_MS))
            .build();

        var request = HttpRequest.newBuilder()
            .uri(URI.create(SMS_API_URL))
            .header("Authorization", "Bearer " + API_KEY)
            .header("Content-Type", "application/json")
            .POST(HttpRequest.BodyPublishers.ofString(
                String.format("{\"to\":\"%s\",\"text\":\"%s\"}", phone, message)))
            .build();

        for (int i = 0; i < MAX_RETRIES; i++) {
            try {
                var response = client.send(request, BodyHandlers.ofString());
                if (response.statusCode() == 200) return;
            } catch (Exception e) {
                if (i == MAX_RETRIES - 1) throw new RuntimeException("SMS failed", e);
            }
        }
    }
}
```

### Problem Analysis

The API key (`sk-prod-8a7b...`) is compiled into the binary: any developer with access to the JAR can extract it. Changing the SMS provider URL or timeout requires a full rebuild and redeploy. The `static final` pattern blocks per-environment overrides — you can't point staging at a sandbox SMS endpoint without editing source code. Hardcoded credentials in source are the #1 cause of credential leaks in Git history.

### ✅ After
```java
@Component
public class SmsNotificationService {

    private final SmsConfig config;
    private final HttpClient httpClient;

    public SmsNotificationService(SmsConfig config) {
        this.config = config;
        this.httpClient = HttpClient.newBuilder()
            .connectTimeout(config.connectTimeout())
            .build();
    }

    public void send(String phone, String message) {
        var payload = Map.of("to", phone, "text", message);
        var request = HttpRequest.newBuilder()
            .uri(config.apiUrl())
            .header("Authorization", "Bearer " + config.apiKey())
            .header("Content-Type", "application/json")
            .POST(HttpRequest.BodyPublishers.ofString(toJson(payload)))
            .timeout(config.requestTimeout())
            .build();

        for (int attempt = 0; attempt < config.maxRetries(); attempt++) {
            try {
                var response = httpClient.send(request, BodyHandlers.ofString());
                if (response.statusCode() == 200) return;
                log.warn("SMS send non-200 status={} attempt={}/{} phone={}",
                    response.statusCode(), attempt + 1, config.maxRetries(), maskPhone(phone));
            } catch (Exception e) {
                if (attempt == config.maxRetries() - 1) {
                    throw new SmsSendFailedException(phone, config.maxRetries(), e);
                }
                log.warn("SMS send attempt {}/{} failed phone={}",
                    attempt + 1, config.maxRetries(), maskPhone(phone), e);
            }
        }
    }
}
```

```java
@ConfigurationProperties(prefix = "app.sms")
public record SmsConfig(
    @NotBlank URI apiUrl,
    @NotBlank String apiKey,
    @Positive int maxRetries,
    Duration connectTimeout,
    Duration requestTimeout
) {
    public SmsConfig {
        maxRetries = maxRetries > 0 ? maxRetries : 3;
        connectTimeout = connectTimeout != null ? connectTimeout : Duration.ofSeconds(5);
        requestTimeout = requestTimeout != null ? requestTimeout : Duration.ofSeconds(10);
    }
}
```

```yaml
app:
  sms:
    api-url: ${SMS_API_URL}
    api-key: ${SMS_API_KEY}
    max-retries: 3
    connect-timeout: 5s
    request-timeout: 10s
```

### Expert Note

C12 (Configuration Externalization): all environment-specific values (`api-url`, `api-key`, timeouts) are read from external configuration via `@ConfigurationProperties` — secrets come from environment variables or a vault, never from source code. C6 (Security by Default): the API key is injected at runtime via `${SMS_API_KEY}`; it never appears in version control. The `SmsConfig` record provides default values defensively in the compact constructor, ensuring the service starts even if optional properties are missing.

---

## E4: Database Queries — N+1 Problem to Batch Loading

### ❌ Before
```python
def get_team_dashboard(team_id: int, db: Session) -> dict:
    members = db.query(User).filter(User.team_id == team_id).all()
    # 1 query for members

    member_summaries = []
    for member in members:
        tasks = db.query(Task).filter(Task.assignee_id == member.id).all()
        # N queries — one per member
        completed = sum(1 for t in tasks if t.status == "done")
        member_summaries.append({
            "name": member.name,
            "total_tasks": len(tasks),
            "completed_tasks": completed,
            "recent_comments": [
                c.body for c in
                db.query(Comment)
                  .filter(Comment.author_id == member.id)
                  .order_by(Comment.created_at.desc())
                  .limit(5)
                  .all()
            ]
            # N more queries — one per member for comments
        })

    return {"team_id": team_id, "members": member_summaries}
```

### Problem Analysis

For a team with 8 members, this function executes `1 + 8 + 8 = 17` database round-trips. For a team with 50 members: 101 queries. Each query is a network round-trip (1-5ms in the same AZ, 10-50ms cross-AZ), turning a function that should run in ~5ms into one that takes 500ms+. Nested N+1 (tasks inside members inside the loop, comments inside that same loop) compounds the problem multiplicatively as the team grows.

### ✅ After
```python
def get_team_dashboard(team_id: int, db: Session) -> dict:
    member_ids_subquery = (
        db.query(User.id)
          .filter(User.team_id == team_id)
          .subquery()
    )

    members = db.query(User).filter(User.team_id == team_id).all()

    tasks = (
        db.query(Task)
          .filter(Task.assignee_id.in_(member_ids_subquery))
          .all()
    )
    tasks_by_member: dict[int, list[Task]] = {}
    for t in tasks:
        tasks_by_member.setdefault(t.assignee_id, []).append(t)

    recent_comments = (
        db.query(Comment)
          .filter(Comment.author_id.in_(member_ids_subquery))
          .order_by(Comment.created_at.desc())
          .all()
    )
    comments_by_author: dict[int, list[Comment]] = {}
    for c in recent_comments:
        author_comments = comments_by_author.setdefault(c.author_id, [])
        if len(author_comments) < 5:
            author_comments.append(c)

    member_summaries = []
    for member in members:
        member_tasks = tasks_by_member.get(member.id, [])
        completed = sum(1 for t in member_tasks if t.status == "done")
        member_comments = comments_by_author.get(member.id, [])
        member_summaries.append({
            "name": member.name,
            "total_tasks": len(member_tasks),
            "completed_tasks": completed,
            "recent_comments": [c.body for c in member_comments[:5]],
        })

    return {"team_id": team_id, "members": member_summaries}
```

### Expert Note

This transforms the query pattern from `1 + 2N` to a constant 3 queries regardless of team size, applying the C2 principle of not just avoiding errors but preventing systemic performance degradation. The code is slightly longer but the performance characteristic is now O(1) database round-trips instead of O(N). For read-heavy dashboards, the next evolution would be a materialized view or a dedicated read-model updated by domain events.

---

## E5: API Evolution — Breaking Change to Versioned Migration

### ❌ Before
```java
@RestController
@RequestMapping("/api/orders")
public class OrderController {

    @GetMapping("/{id}")
    public OrderResponse getOrder(@PathVariable Long id) {
        var order = orderService.findById(id);
        return new OrderResponse(
            order.id(),
            order.total(),
            order.status(),
            order.items().stream()
                .map(i -> new OrderItemResponse(i.sku(), i.price(), i.quantity()))
                .toList()
        );
    }
}

// Six months later — the API is changed in-place:
public record OrderResponse(
    Long id,
    BigDecimal total,          // was BigDecimal
    String status,
    String discountedTotal,    // NEW field — old clients break on unknown JSON
    List<OrderItemResponse> items
) {}

public record OrderItemResponse(
    String sku,
    BigDecimal price,          // was BigDecimal
    int quantity,              // was int — but wait, someone changed it to double
    double unitWeightKg        // NEW mandatory field — all old clients crash
) {}
```

### Problem Analysis

Adding `discountedTotal` and `unitWeightKg` as mandatory fields silently breaks every existing mobile app, web client, and third-party integration that was built against the original contract. The `BigDecimal` → `String` change on `total` is a type-breaking change with no migration path. There is no mechanism to communicate the deprecation timeline to API consumers, and no way to run v1 and v2 side-by-side during migration.

### ✅ After
```java
// === v1 — preserved exactly as-is, fully backward compatible ===
@RestController
@RequestMapping("/api/v1/orders")
public class OrderControllerV1 {

    @GetMapping("/{id}")
    public OrderResponseV1 getOrder(@PathVariable Long id) {
        var order = orderService.findById(id);
        return new OrderResponseV1(
            order.id(), order.total(), order.status(),
            order.items().stream()
                .map(i -> new OrderItemResponseV1(i.sku(), i.price(), i.quantity()))
                .toList()
        );
    }
}

public record OrderResponseV1(
    Long id,
    BigDecimal total,
    String status,
    List<OrderItemResponseV1> items
) {}

public record OrderItemResponseV1(
    String sku,
    BigDecimal price,
    int quantity
) {}

// === v2 — new features, clean contract ===
@RestController
@RequestMapping("/api/v2/orders")
public class OrderControllerV2 {

    @GetMapping("/{id}")
    public OrderResponseV2 getOrder(@PathVariable Long id) {
        var order = orderService.findById(id);
        var discount = discountEngine.compute(order);
        return new OrderResponseV2(
            order.id(), order.total(), order.status(),
            order.items().stream()
                .map(i -> new OrderItemResponseV2(
                    i.sku(), i.price(), i.quantity(), i.weightKg()))
                .toList(),
            discount.discountedTotal(),
            discount.breakdown()
        );
    }
}

public record OrderResponseV2(
    Long id,
    BigDecimal total,
    String status,
    List<OrderItemResponseV2> items,
    BigDecimal discountedTotal,
    List<String> discountBreakdown
) {}

public record OrderItemResponseV2(
    String sku,
    BigDecimal price,
    int quantity,
    double unitWeightKg
) {}

// === Deprecation headers on v1 ===
@GetMapping("/api/v1/orders/{id}")
public ResponseEntity<OrderResponseV1> getOrderV1(@PathVariable Long id) {
    var body = orderService.findById(id);
    return ResponseEntity.ok()
        .header("Deprecation", "true")
        .header("Sunset", "Sun, 31 Dec 2026 23:59:59 GMT")
        .header("Link", "</api/v2/orders/" + id + ">; rel=\"successor-version\"")
        .body(buildV1Response(body));
}
```

### Expert Note

C13 (Backward Compatibility): `/api/v1` is frozen and never modified — existing clients continue to work indefinitely. The `Deprecation`, `Sunset`, and `Link` response headers follow the IETF Deprecation HTTP Header draft, allowing automated tooling to detect deprecated APIs. C14 (Documentation Sync): the v1 → v2 migration is self-documenting because the URI namespace itself encodes the version, and the `Link` header points directly to the successor.
