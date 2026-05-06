# API Lifecycle Management — Principal Architect Reference

## Purpose

Governance patterns for APIs from birth to deprecation. Every API will evolve, break, and eventually die. The architect's job is to manage this lifecycle so consumers are never surprised and producers are never trapped.

---

## AL-1: API Versioning Strategy

**Use when**: An API has consumers outside your team. Versioning is the API contract's most fundamental promise.

### ❌ Wrong — No Versioning, Direct Breaking Changes

```java
@RestController
@RequestMapping("/api")
public class OrderController {

    // v1 — deployed 2025
    @GetMapping("/orders")
    public List<OrderV1Rs> listOrders() { ... }

    // "We need to change the response format" →
    // Just change the method. Update all callers simultaneously.
    // Reality: 3 consumers still on old format → broken. Rollback. Fire.
}

// Consumer breaks:
// Expects: [{"id":1, "total":"99.99"}]  (String total)
// Gets:    [{"id":1, "total":99.99}]    (Number total) → deserialization failure
```

### ✅ Expert Fix — URL Path Versioning with Backward Compatibility

```java
// V1 — stable, never changes
@RestController
@RequestMapping("/api/v1")
public class OrderControllerV1 {

    @GetMapping("/orders")
    @DeprecatedSince("2026-06") // marks for consumers
    public List<OrderRsV1> listOrders() {
        // V1 format preserved FOREVER (or until deprecation window closes)
        return orderService.listOrdersV1();
    }
}

// V2 — new format, clean API
@RestController
@RequestMapping("/api/v2")
public class OrderControllerV2 {

    @GetMapping("/orders")
    public List<OrderRsV2> listOrders(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "createdAt") String sort) {
        // V2: paginated, sortable, new format
        return orderService.listOrdersV2(new PageRequest(page, Math.min(size, 100)));
    }
}
```

```java
// Internal adapter — V2 internally calls V1 where logic unchanged
// Avoids code duplication while keeping API contracts clean
@Service
public class OrderService {

    public List<OrderRsV1> listOrdersV1() {
        return repository.findAll().stream()
            .map(OrderMapper::toV1)
            .toList();
    }

    public List<OrderRsV2> listOrdersV2(PageRequest page) {
        return repository.findAll(page.toPageable()).stream()
            .map(OrderMapper::toV2)
            .toList();
    }
}
```

**Versioning Strategy Decision:**

| Strategy | Pros | Cons | Best For |
|----------|------|------|----------|
| **URL Path** (`/v1/`, `/v2/`) | Simple, visible, cacheable | URL litter, routing complexity | Public REST APIs |
| **Header** (`Accept: vnd.api+v2`) | Clean URLs | Hard to discover, cache issues | Internal APIs |
| **Query Param** (`?version=2`) | Very simple | Easy to ignore, cache issues | Internal tools |
| **Content Negotiation** | Standards-compliant | Complex, poor tooling | Rare — avoid |

**Expert Note**: URL path versioning is the pragmatic default. It's visible in every log, every dashboard, every curl command. A consumer debugging an issue instantly knows what version they're calling. The cost — URL litter — is trivial compared to the benefit of instant version identification. Internal V2 → V1 adapter pattern keeps business logic DRY while API contracts stay clean.

---

## AL-2: API Deprecation Lifecycle

**Use when**: An API version must be retired. Deprecation is a communication process, not a delete button.

### ❌ Wrong — Sudden Removal

```
2026-01: "We're removing /api/v1/orders on March 1st."
2026-03-01: /api/v1/orders returns 404.
3 teams not migrated. 2 didn't see the email. 1 was on vacation.
```

### ✅ Expert Fix — Sunset Header + Deprecation Window

```java
// Deprecation communication — layered, gradual, automated
@RestController
@RequestMapping("/api/v1")
public class OrderControllerV1 {

    @GetMapping("/orders")
    @DeprecatedSince("2026-06-15")  // internal marker
    public ResponseEntity<List<OrderRsV1>> listOrders() {
        var orders = orderService.listOrdersV1();

        return ResponseEntity.ok()
            // Every response carries deprecation notice
            .header("Sunset", "Sat, 31 Dec 2026 23:59:59 GMT")
            .header("Deprecation", "true")
            .header("Link", "</api/v2/orders{?page,size,sort}>; rel=\"successor-version\"")
            .header("API-Version-Warning", "v1 will be removed on 2027-01-01. Migrate to v2.")
            .body(orders);
    }
}
```

```java
// Monitoring: track v1 usage and alert consumers
@Component
public class ApiVersionMonitor {

    @EventListener
    public void onApiCall(ApiCallEvent event) {
        if (event.version() == 1) {
            metrics.v1CallCount.increment();

            // Weekly report to consumer teams
            if (metrics.v1CallCount.get() > 0) {
                deprecationTracker.recordUsage(event.consumerId(), event.endpoint());
            }

            // Alert: deprecation deadline approaching
            if (LocalDate.now().plusDays(30).isAfter(event.sunsetDate())) {
                notifyConsumerTeam(event.consumerId(),
                    "API v1 deprecation: %d days remaining. Your v1 call count: %d/week"
                    .formatted(ChronoUnit.DAYS.between(LocalDate.now(), event.sunsetDate()),
                        metrics.v1CallCount.weekly()));
            }
        }
    }
}
```

**Deprecation Timeline:**
```
T-180d:  Announce deprecation (email, changelog, API changelog endpoint)
T-150d:  Sunset header added to all v1 responses
T-90d:   Deprecation warning logs for every v1 call (visible in consumer dashboards)
T-60d:   Weekly usage reports to consumers still on v1
T-30d:   Daily reminders. Direct outreach to teams > 0 calls.
T-0:     v1 removed → returns 410 Gone (not 404 — "it WAS here, it's GONE")
T+0:     v1 removed. Sunset complete.
```

```java
@RestControllerAdvice
public class DeprecatedEndpointHandler {

    @GetMapping("/api/v1/**")
    public ResponseEntity<ApiSunsetResponse> handleDeprecatedEndpoint(HttpServletRequest req) {
        // After sunset date: 410 Gone — semantically correct
        return ResponseEntity.status(HttpStatus.GONE)
            .header("Sunset", "Sat, 31 Dec 2026 23:59:59 GMT")
            .body(new ApiSunsetResponse(
                "API v1 was retired on 2027-01-01.",
                "https://docs.example.com/migration/v1-to-v2",
                "/api/v2/orders"));
    }
}

public record ApiSunsetResponse(
    String message,
    String migrationGuideUrl,
    String successorEndpoint
) {}
```

**Expert Note**: Deprecation is a communication problem, not a technical one. The Sunset header (RFC 8594) is the standard. The 410 Gone status code is crucial — it tells consumers "this was intentionally removed" vs 404 "maybe the URL is wrong." Never delete an API without notice. The deprecation window for public APIs should be 6-12 months. For internal APIs, 3 months is acceptable if communication is direct.

---

## AL-3: API Gateway Patterns

**Use when**: Managing 10+ microservices exposed to external consumers. An API Gateway is the architectural boundary between internal and external.

### ❌ Wrong — Direct Service Exposure

```
External consumers call order-service:8080, payment-service:8081,
inventory-service:8082 directly.

Problems:
- CORS issues on every service
- Auth implemented differently (or not) on each service
- Rate limiting per service — inconsistent
- No request/response transformation
- Changing internal architecture breaks consumers
```

### ✅ Expert Fix — Gateway as Architectural Boundary

```yaml
# Spring Cloud Gateway — routing configuration
spring:
  cloud:
    gateway:
      default-filters:
        - RemoveResponseHeader=X-Internal-*   # strip internal headers
        - AddResponseHeader=X-Gateway, true

      routes:
        # External API — rate limited, authenticated
        - id: orders-external
          uri: lb://order-service
          predicates:
            - Path=/api/v2/orders/**
          filters:
            - name: RequestRateLimiter
              args:
                redis-rate-limiter.replenishRate: 100
                redis-rate-limiter.burstCapacity: 200
            - StripPrefix=0

        # Internal API — no rate limit, mtls-only
        - id: orders-internal
          uri: lb://order-service
          predicates:
            - Path=/internal/orders/**
            - Header=X-Internal-Auth, true

        # Payment — CRITICAL route, highest rate limit
        - id: payments
          uri: lb://payment-service
          predicates:
            - Path=/api/v2/payments/**
          filters:
            - name: RequestRateLimiter
              args:
                redis-rate-limiter.replenishRate: 1000
                redis-rate-limiter.burstCapacity: 2000
            - name: CircuitBreaker
              args:
                name: paymentCircuitBreaker
                fallbackUri: forward:/fallback/payment
```

**Gateway Responsibilities (Architectural Layers):**
```
┌─────────────────────────────────────────────────────────┐
│                    API Gateway                           │
├─────────────────────────────────────────────────────────┤
│ Layer 1: Security    — Auth, Rate Limiting, IP Filtering │
│ Layer 2: Routing     — Path → Service, Load Balancing   │
│ Layer 3: Transform   — Request/Response modification    │
│ Layer 4: Resilience  — Circuit Breaker, Retry, Timeout  │
│ Layer 5: Observability — Metrics, Tracing, Logging      │
└─────────────────────────────────────────────────────────┘
```

**Expert Note**: The API Gateway is the single most important architectural component for external-facing microservices. It should NEVER contain business logic — it is purely infrastructure. Business logic in the gateway is the #1 gateway anti-pattern (it becomes a new monolith). Each concern (auth, rate limit, routing) should be a plugin, not embedded code. The gateway is the place where internal complexity becomes external simplicity.

---

## AL-4: API Contract Testing

**Use when**: Multiple teams consume your API. Contract tests verify the API promise independently of implementation.

### ❌ Wrong — "Just Test the Implementation"

```java
// E2E test: calls real order-service, real DB, real auth.
// Passes locally. Passes in CI. Fails when consumer team's mock diverges.
// Consumer says "your API broke." Provider says "our tests pass."

@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
class OrderApiTest {
    @Test
    void testListOrders() {
        // Tests implementation, NOT contract
        var response = restTemplate.getForEntity("/api/v2/orders", OrderRsV2[].class);
        assertThat(response.getStatusCode()).isEqualTo(200);
        // What if consumer expects 'items' field but we send 'lineItems'?
        // This test doesn't catch the naming mismatch.
    }
}
```

### ✅ Expert Fix — Consumer-Driven Contract Tests (Pact)

```java
// Provider test — verifies we satisfy the consumer's contract
@Provider("order-service")
@PactBroker(url = "${pact.broker.url}")
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
class OrderServicePactProviderTest {

    @LocalServerPort
    private int port;

    @BeforeEach
    void setup(PactVerificationContext context) {
        context.setTarget(new HttpTestTarget("localhost", port));
    }

    @TestTemplate
    @ExtendWith(PactVerificationInvocationContextProvider.class)
    void verifyPact(PactVerificationContext context) {
        context.verifyInteraction();
    }

    @State("orders exist for user 999")
    void setupOrders() {
        orderRepo.save(new Order(999L, "PENDING", new Money("99.99")));
    }
}
```

```java
// Consumer pact — defines the contract we expect
@ExtendWith(PactConsumerTestExt.class)
class OrderServicePactConsumerTest {

    @Pact(consumer = "mobile-app", provider = "order-service")
    public V4Pact listOrdersPact(PactDslWithProvider builder) {
        return builder
            .given("orders exist for user 999")
            .uponReceiving("GET list orders")
                .path("/api/v2/orders")
                .query("userId=999&page=0&size=20")
                .method("GET")
            .willRespondWith()
                .status(200)
                .headers(Map.of("Content-Type", "application/json"))
                .body(newJsonBody(body -> {
                    body.stringType("orderId", "12345");
                    body.stringType("status", "PENDING");
                    body.decimalType("totalAmount", "99.99");  // CONTRACT: field name & type
                }).build())
            .toPact(V4Pact.class);
    }

    @Test
    @PactTestFor(pactMethod = "listOrdersPact")
    void testListOrders(MockServer mockServer) {
        var client = new OrderApiClient(mockServer.getUrl());
        var orders = client.listOrders(999L, 0, 20);
        assertThat(orders).hasSize(1);
        assertThat(orders.get(0).orderId()).isEqualTo("12345");
    }
}
```

**Contract Testing Pipeline:**
```
[Consumer writes contract] → [Pact Broker stores]
    → [Provider CI verifies contract] → [Pact Broker: ✅ verified]
    → [Consumer deploys knowing contract is satisfied]
    → [Provider deploys knowing no consumer will break]

If provider changes field name:
    → Pact verification FAILS → provider CI blocks deploy
    → Provider knows: "mobile-app expects 'totalAmount', we renamed to 'total'"
```

**Expert Note**: Contract tests solve the "works on my machine" problem between teams. The Pact Broker is the source of truth for API compatibility — any provider deploy that breaks a consumer's contract is blocked BEFORE reaching production. This is not optional for multi-team organizations — without contract testing, every deploy is a gamble.

---

## AL-5: API Documentation as Code

**Use when**: API consumers need accurate, always-up-to-date documentation. Hand-written docs diverge from code within one sprint.

### ❌ Wrong — Confluence/Wiki API Docs

```
"Documentation is in Confluence. Just search for Order API."
Confluence page: "Last updated 2025-11." Actual API deployed 2026-05.
3 new endpoints missing. 2 deprecated endpoints still listed.
Consumer wastes 4 hours implementing against stale docs.
```

### ✅ Expert Fix — OpenAPI as Source of Truth

```java
@RestController
@RequestMapping("/api/v2")
@Tag(name = "Orders", description = "Order management API v2")
public class OrderControllerV2 {

    @Operation(
        summary = "List user orders",
        description = "Returns paginated list of orders for a user. V2 adds sorting and filtering.",
        deprecated = false
    )
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Orders retrieved",
            content = @Content(schema = @Schema(implementation = OrderRsV2.class))),
        @ApiResponse(responseCode = "401", description = "Unauthorized"),
        @ApiResponse(responseCode = "429", description = "Rate limit exceeded",
            headers = @Header(name = "Retry-After", description = "Seconds to wait"))
    })
    @GetMapping("/orders")
    public PageResponse<OrderRsV2> listOrders(
            @Parameter(description = "Zero-based page index", example = "0")
            @RequestParam(defaultValue = "0") int page,

            @Parameter(description = "Page size (max 100)", example = "20")
            @RequestParam(defaultValue = "20") int size,

            @Parameter(description = "Sort field", example = "createdAt")
            @RequestParam(defaultValue = "createdAt") String sort) {
        return orderService.listOrdersV2(new PageRequest(page, Math.min(size, 100)));
    }
}
```

```yaml
# OpenAPI generation in build — documentation IS the build artifact
springdoc:
  api-docs:
    path: /api-docs
  swagger-ui:
    path: /swagger-ui.html
  default-produces-media-type: application/json
  writer-with-order-by-keys: true

# Auto-generate client SDKs from OpenAPI
# ./gradlew openApiGenerate → generates Java/Kotlin/TypeScript clients
```

```yaml
# CI check: documentation must match implementation
openapi-diff:
  steps:
    - name: Check API docs are current
      run: |
        openapi-diff \
          --old docs/openapi/v2-orders-current.yaml \
          --new http://staging-order-service/api-docs
        # FAIL if diff found → docs MUST be updated in this PR
```

**Expert Note**: API documentation that is not generated from code is documentation that is already wrong. The OpenAPI spec should be the single source of truth — code generates spec, spec generates docs, spec generates client SDKs. The CI check ensures docs are never stale. When a field is added, the OpenAPI spec changes, the docs update automatically, and consumer SDKs can regenerate. One change, three artifacts updated automatically.

---

## Quick API Lifecycle Checklist

- [ ] Versioning strategy documented (URL path / header / query)?
- [ ] At most 2 active API versions (N and N-1)?
- [ ] Sunset header on all deprecated endpoints (RFC 8594)?
- [ ] Deprecation window: 6-12 months public, 3 months internal?
- [ ] 410 Gone returned after deprecation (not 404)?
- [ ] API Gateway as boundary — no direct internal service exposure?
- [ ] Gateway responsibilities layered: Security → Routing → Transform → Resilience → Obs?
- [ ] No business logic in gateway (pure infrastructure)?
- [ ] Contract tests (Pact/Spring Cloud Contract) running in CI?
- [ ] Pact Broker as source of truth for cross-team API compatibility?
- [ ] OpenAPI spec auto-generated from code annotations?
- [ ] CI enforces: OpenAPI spec matches implementation (openapi-diff)?
- [ ] Client SDKs auto-generated from OpenAPI spec?
- [ ] API changelog auto-generated from git history (Conventional Commits)?
