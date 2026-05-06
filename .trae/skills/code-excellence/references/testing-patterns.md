# Testing Patterns

## Purpose

Expert-level testing is not about writing more tests — it's about writing the **right** tests
with the **right** structure. This reference encodes testing patterns that produce reliable,
maintainable test suites.

---

## Pattern: Given-When-Then Structure

Every test should follow this structure. It makes tests readable, debuggable, and self-documenting.

### Java (JUnit 5)
```java
@Test
@DisplayName("when order is cancelled, refund is issued and inventory is released")
void whenOrderCancelled_refundIssuedAndInventoryReleased() {
    // Given
    var order = new Order(userId = 1L, items = List.of(new Item("SKU-1", price = 100)));
    order.confirm();
    paymentGateway.stubChargeSuccess();

    // When
    order.cancel();

    // Then
    assertThat(order.status()).isEqualTo(CANCELLED);
    assertThat(refundGateway.issuedRefunds()).hasSize(1);
    assertThat(inventoryService.releasedStock("SKU-1")).isEqualTo(1);
}
```

### Kotlin (Kotest)
```kotlin
"when order cancelled, refund is issued" {
    // Given
    val order = Order(userId = 1L, items = listOf(Item("SKU-1", price = 100)))
    order.confirm()

    // When
    order.cancel()

    // Then
    order.status shouldBe CANCELLED
    refundGateway.issuedRefunds() shouldHaveSize 1
}
```

### Python (pytest)
```python
def test_when_order_cancelled_refund_issued():
    # Given
    order = Order(user_id=1, items=[Item(sku="SKU-1", price=100)])
    order.confirm()

    # When
    order.cancel()

    # Then
    assert order.status == Status.CANCELLED
    assert refund_gateway.issued_refunds() == 1
```

---

## Pattern: Table-Driven Tests

When the same logic has multiple input/output scenarios, use table-driven tests.

### Java
```java
@ParameterizedTest(name = "discount for {0} items = {1}")
@CsvSource({
    "1, 0",       // no discount
    "5, 10",      // 10% for 5+
    "10, 20",     // 20% for 10+
    "100, 20"     // capped at 20%
})
void calculateDiscount(int quantity, int expectedDiscountPercent) {
    var calculator = new DiscountCalculator();
    assertThat(calculator.discountPercent(quantity)).isEqualTo(expectedDiscountPercent);
}
```

### Go
```go
func TestCalculateDiscount(t *testing.T) {
    tests := []struct {
        name     string
        quantity int
        want     int
    }{
        {"no discount", 1, 0},
        {"10% for 5+", 5, 10},
        {"20% for 10+", 10, 20},
        {"capped at 20%", 100, 20},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := CalculateDiscount(tt.quantity)
            assert.Equal(t, tt.want, got)
        })
    }
}
```

### Python
```python
@pytest.mark.parametrize("quantity,expected", [
    (1, 0),    # no discount
    (5, 10),   # 10% for 5+
    (10, 20),  # 20% for 10+
    (100, 20), # capped at 20%
])
def test_calculate_discount(quantity, expected):
    assert calculate_discount(quantity) == expected
```

---

## Pattern: Arrange-Act-Assert with Fixtures

For complex setup, extract fixtures to keep tests focused.

### Java — Test Fixtures
```java
class OrderTestFixtures {
    static Order createOrderWithItems(int itemCount) {
        var items = IntStream.range(0, itemCount)
            .mapToObj(i -> new Item("SKU-" + i, price = 100))
            .toList();
        return new Order(userId = 1L, items);
    }
}

@Test
void largeOrder_appliesMaximumDiscount() {
    var order = OrderTestFixtures.createOrderWithItems(10);
    order.confirm();
    // ...
}
```

### Python — pytest Fixtures
```python
@pytest.fixture
def confirmed_order(db_session):
    user = User(id=1, name="Alice")
    db_session.add(user)
    order = Order(user_id=1, items=[Item(sku="SKU-1", price=100)])
    order.confirm()
    db_session.commit()
    return order

def test_cancelled_order_has_refund(confirmed_order):
    confirmed_order.cancel()
    assert confirmed_order.refund_issued
```

---

## Pattern: Test Doubles Strategy

| Double | When to Use | Example |
|--------|-------------|---------|
| **Stub** | Predictable data source | Fake clock, random number generator |
| **Mock** | Verify interactions | External API called with correct params |
| **Spy** | Rarely needed — usually a smell | Verify internal method calls |
| **Fake** | Full in-memory implementation | InMemoryRepository, FakePaymentGateway |

**Rule of thumb**: Prefer **Fakes** over Mocks. A fake implements the same interface as the real component but uses in-memory storage. It tests behaviour, not interaction details.

```java
// Fake implementation
class InMemoryOrderRepository implements OrderRepository {
    private final Map<Long, Order> orders = new ConcurrentHashMap<>();
    @Override public Optional<Order> findById(Long id) { return Optional.ofNullable(orders.get(id)); }
    @Override public Order save(Order order) { orders.put(order.id(), order); return order; }
}

@Test
void testWithFake() {
    var repo = new InMemoryOrderRepository();
    var service = new OrderService(repo, ...);
    // Test behaves like production — no mocking framework needed
}
```

---

## Pattern: Integration Test with Testcontainers

For tests that need real infrastructure, use containers.

### Java
```java
@Testcontainers
class OrderIntegrationTest {
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Test
    void createOrder_persizesCorrectly() {
        // Uses real PostgreSQL — tests actual query execution
    }
}
```

### Python
```python
@pytest.fixture(scope="session")
def postgres_container():
    with PostgresContainer("postgres:16") as postgres:
        yield postgres.get_connection_url()

@pytest.fixture
def db(postgres_container):
    engine = create_async_engine(postgres_container)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
```

---

## Pattern: Property-Based Testing

Instead of testing specific inputs, test properties that should hold for ALL inputs.

### Python (Hypothesis)
```python
@given(st.lists(st.integers(min_value=1), min_size=1))
def test_total_is_sum_of_items(items):
    order = Order(items=[Item(sku=f"SKU-{i}", price=p) for i, p in enumerate(items)])
    assert order.total == sum(items)

@given(st.dates(), st.dates())
def test_end_date_after_start(date1, date2):
    if date1 > date2:
        date1, date2 = date2, date1  # normalize
    period = Period(start=date1, end=date2)
    assert period.end >= period.start
```

---

## Testing Anti-Patterns to Avoid

| Anti-Pattern | Why It's Bad | Fix |
|-------------|-------------|-----|
| Testing private methods | Breaks refactoring, tests implementation not behaviour | Test through public API |
| Over-mocking | Tests the mock setup, not the real code | Use Fakes instead |
| Test order dependency | Tests pass/fail based on execution order | Each test is independent |
| Giant test fixtures | One fixture tries to cover everything | Specific fixtures per test |
| Asserting implementation details | `verify(mock).privateMethod()` called | Assert the output / state change |
| No negative tests | Only happy path covered | Add error path and edge case tests |
| String matching in assertions | `assert str(result) == "Order(id=1)"` | Assert specific fields |

---

## Test Coverage Targets (by Context)

| Context | Unit Tests | Integration | E2E | Notes |
|---------|-----------|-------------|-----|-------|
| Startup MVP | ~40% | Manual | Smoke | Focus on critical paths |
| Scale-Up | 80%+ | Testcontainers | Critical journeys | Core domain must be well covered |
| Enterprise | 90%+ | Every integration | Full regression | Mutation testing to verify test quality |
| Critical Infra | 95%+ | Chaos engineering | Synthetic monitoring | Property-based + mutation testing |

---

## Pattern: Chaos Engineering

**Use when**: You operate distributed systems where partial failures are inevitable and need to verify resilience before production incidents occur.

**Rule**: Start in non-production, define a steady-state hypothesis, run the smallest blast-radius experiment first, and always have an abort condition.

### Chaos Monkey (Netflix) — Instance Termination

```java
@ChaosExperiment
@DisplayName("when catalog-service instance is terminated, requests fallback to cache")
void whenInstanceTerminated_requestsFallbackToCache() {
    // Given: steady state with warm cache
    var steadyState = catalogService.getProduct("SKU-1");
    assertThat(steadyState).isPresent();
    cacheManager.warm("SKU-1", steadyState.get());

    // When: terminate one catalog-service instance
    chaosMonkey.terminateInstance("catalog-service", 1);

    // Then: requests still succeed via cache fallback
    await().atMost(Duration.ofSeconds(10))
        .pollInterval(Duration.ofMillis(500))
        .untilAsserted(() -> {
            var fallback = catalogService.getProduct("SKU-1");
            assertThat(fallback).isPresent();
            assertThat(metrics.getCacheHits("catalog")).isGreaterThan(0);
        });
}
```

### Gremlin — CPU Attack Template (YAML)

```yaml
apiVersion: gremlin.com/v1
kind: Attack
metadata:
  name: catalog-service-cpu-stress
  labels:
    app: catalog-service
    env: staging
spec:
  type: cpu
  command:
    length: 120
    amount: 80
    percent: 50
  targets:
    selector:
      - label: "app=catalog-service"
  abortConditions:
    - metric: p99Latency
      threshold: 2000ms
      operator: greaterThan
    - metric: errorRate
      threshold: 5%
      operator: greaterThan
```

### Litmus — Pod Delete Experiment (Kubernetes)

```yaml
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: order-service-pod-delete
  namespace: chaos
spec:
  appinfo:
    appns: 'default'
    applabel: 'app=order-service'
    appkind: 'deployment'
  annotationCheck: 'true'
  engineState: 'active'
  chaosServiceAccount: litmus-admin
  experiments:
    - name: pod-delete
      spec:
        components:
          env:
            - name: TOTAL_CHAOS_DURATION
              value: '30'
            - name: CHAOS_INTERVAL
              value: '10'
            - name: FORCE
              value: 'false'
            - name: PODS_AFFECTED_PERC
              value: '33'
          probe:
            - name: "order-health-check"
              type: "httpProbe"
              mode: "Continuous"
              runProperties:
                probeTimeout: '5s'
                retry: 2
                interval: '5s'
                probePollingInterval: '2s'
              httpProbe/inputs:
                url: "http://order-service.default.svc.cluster.local:8080/actuator/health"
                insecureSkipVerify: false
                method:
                  get:
                    criteria: "=="
                    responseCode: "200"
```

**Expert note**: Run chaos experiments during business hours with the team on-call. The goal is to learn, not to surprise. Document every unexpected behaviour as a new regression test.

---

## Pattern: Fault Injection Testing

**Use when**: You need to validate how a service behaves under specific infrastructure faults — network latency, dependency downtime, disk exhaustion, or connection pool saturation.

**Rule**: Inject faults at the infrastructure or transport layer, never by modifying application code under test. Measure recovery time (MTTR) and degradation boundaries.

### Network Latency Injection (Java + Toxiproxy)

```java
@Testcontainers
class NetworkLatencyFaultInjectionTest {

    @Container
    static ToxiproxyContainer toxiproxy = new ToxiproxyContainer("ghcr.io/shopify/toxiproxy:2.5.0");

    @Test
    @DisplayName("when payment-gateway latency exceeds 3s, circuit breaker opens")
    void whenLatencyExceedsThreshold_circuitBreakerOpens() {
        var proxy = toxiproxy.getProxy(paymentGatewayHost, 8080);
        proxy.toxics().latency("latency", ToxicDirection.DOWNSTREAM, 3500);

        var order = OrderFixtures.createConfirmedOrder();

        assertThatThrownBy(() -> orderService.charge(order))
            .isInstanceOf(CircuitBreakerOpenException.class);

        assertThat(circuitBreaker.state()).isEqualTo(State.OPEN);
    }
}
```

### Service Downtime Injection (Java + Testcontainers)

```java
@Test
@DisplayName("when inventory-service is down, order creation returns 503 with retry-after header")
void whenInventoryServiceDown_orderReturns503WithRetryAfter() {
    // Given: inventory container is paused (simulating network partition)
    inventoryContainer.getDockerClient().pauseContainerCmd(inventoryContainer.getContainerId()).exec();

    // When
    var response = restTemplate.postForEntity("/orders", orderRequest, ErrorResponse.class);

    // Then
    assertThat(response.getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
    assertThat(response.getHeaders().getFirst(HttpHeaders.RETRY_AFTER)).isEqualTo("30");

    // Cleanup
    inventoryContainer.getDockerClient().unpauseContainerCmd(inventoryContainer.getContainerId()).exec();
}
```

### Resource Exhaustion — Connection Pool Saturation

```java
@Test
@DisplayName("when connection pool is exhausted, new requests are queued and eventually timeout")
void whenConnectionPoolExhausted_requestsAreQueuedAndTimeout() {
    var config = new HikariConfig();
    config.setMaximumPoolSize(2);
    config.setConnectionTimeout(1000);
    var dataSource = new HikariDataSource(config);

    // Exhaust the pool
    var connections = IntStream.range(0, 2)
        .mapToObj(i -> dataSource.getConnection())
        .toList();

    // Attempt a third connection
    assertThatThrownBy(() -> dataSource.getConnection())
        .isInstanceOf(SQLException.class)
        .hasMessageContaining("connection timeout");

    connections.forEach(Connection::close);
}
```

### Disk Failure Simulation (Linux /tmp mount)

```yaml
# docker-compose.fault.yml for local disk-full simulation
version: "3.8"
services:
  order-service:
    image: order-service:latest
    volumes:
      - type: tmpfs
        target: /data
        tmpfs:
          size: 10M
    environment:
      - STORAGE_PATH=/data
    # Fill the disk inside the container:
    # dd if=/dev/zero of=/data/fill bs=1M count=11
```

**Expert note**: Fault injection tests must be idempotent and clean up injected faults in `@AfterEach` or `finally` blocks. A left-over toxic proxy or paused container will poison the next test run.

---

## Pattern: Consumer-Driven Contract Testing (Pact)

**Use when**: Multiple services communicate via HTTP/ messaging APIs and you want to prevent breaking changes without expensive integration test suites.

**Rule**: The consumer defines the contract; the provider verifies it. Never share contracts via email or chat — use a Pact Broker.

### Consumer Test (Java + JUnit 5)

```java
@PactTestFor(providerName = "inventory-service")
class InventoryServiceConsumerPactTest {

    @Pact(consumer = "order-service")
    RequestResponsePact reserveStockPact(PactDslWithProvider builder) {
        return builder
            .given("product SKU-1 exists with stock 100")
            .uponReceiving("reserve stock for SKU-1")
            .path("/inventory/reserve")
            .method("POST")
            .headers("Content-Type", "application/json")
            .body(new PactDslJsonBody()
                .stringType("sku", "SKU-1")
                .integerType("quantity", 5))
            .willRespondWith()
            .status(200)
            .body(new PactDslJsonBody()
                .stringType("reservationId", "RES-123")
                .integerType("reservedQuantity", 5)
                .stringType("status", "CONFIRMED"))
            .toPact();
    }

    @Test
    @PactTestFor(pactMethod = "reserveStockPact")
    void reserveStock_returnsReservationDetails(MockServer mockServer) {
        var client = new InventoryClient(mockServer.getUrl());
        var response = client.reserveStock("SKU-1", 5);

        assertThat(response.reservationId()).isNotBlank();
        assertThat(response.status()).isEqualTo("CONFIRMED");
    }
}
```

### Provider Verification (Java + JUnit 5 + Spring)

```java
@Provider("inventory-service")
@PactBroker(url = "https://pact-broker.internal", authentication = @PactBrokerAuth(token = "${PACT_TOKEN}"))
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.DEFINED_PORT)
class InventoryServiceProviderVerificationTest {

    @TestTemplate
    @ExtendWith(PactVerificationInvocationContextProvider.class)
    void pactVerificationTestTemplate(PactVerificationContext context) {
        context.verifyInteraction();
    }

    @BeforeEach
    void before(PactVerificationContext context) {
        context.setTarget(new HttpTestTarget("localhost", 8080));
    }

    @State("product SKU-1 exists with stock 100")
    void sku1ExistsWithStock() {
        inventoryRepository.save(new Stock("SKU-1", 100));
    }
}
```

### CI Pipeline — Pact Broker Can-I-Deploy Gate

```yaml
# .github/workflows/contract-verify.yml
name: Contract Verification
on:
  push:
    branches: [main]
  pull_request:

jobs:
  consumer:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run consumer Pact tests
        run: ./mvnw test -pl order-service -Dtest="*PactTest"
      - name: Publish pacts
        run: |
          ./mvnw pact:publish -pl order-service \
            -Dpact.broker.url=$PACT_BROKER_URL \
            -Dpact.broker.token=$PACT_TOKEN \
            -Dpact.consumer.appVersion=${{ github.sha }} \
            -Dpact.consumer.branch=${{ github.ref_name }}

  provider:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Verify provider against pacts
        run: ./mvnw test -pl inventory-service -Dtest="*ProviderVerificationTest"
      - name: Can I deploy?
        run: |
          docker run --rm pactfoundation/pact-cli \
            broker can-i-deploy \
            --pact-broker-base-url $PACT_BROKER_URL \
            --pact-broker-token $PACT_TOKEN \
            --pacticipant inventory-service \
            --version ${{ github.sha }} \
            --to-environment staging
```

**Expert note**: A passing contract test does NOT guarantee the provider behaves correctly — it only guarantees the consumer's expectations are met. Always pair contract tests with provider-side state management (`@State` methods) to ensure realistic data.

---

## Pattern: Visual Regression Testing

**Use when**: Your application has a UI whose pixel-perfect rendering is critical — design systems, checkout flows, dashboards — and CSS or component changes frequently cause unintended layout shifts.

**Rule**: Baseline images must be generated on the same browser engine, OS, and viewport size. Never approve visual diffs without human review.

### Percy + Selenium (Java)

```java
class CheckoutPageVisualTest {

    WebDriver driver;
    Percy percy;

    @BeforeEach
    void setUp() {
        driver = new ChromeDriver();
        percy = new Percy(driver);
    }

    @Test
    @DisplayName("checkout page renders correctly on desktop")
    void checkoutPage_rendersCorrectlyOnDesktop() {
        driver.manage().window().setSize(new Dimension(1280, 720));
        driver.get("http://localhost:3000/checkout");

        percy.snapshot("Checkout Page - Desktop", List.of(
            new Percy.SnapshotOptions.Builder()
                .widths(List.of(1280, 1440))
                .minHeight(1024)
                .build()
        ));
    }

    @Test
    @DisplayName("checkout page renders correctly on mobile")
    void checkoutPage_rendersCorrectlyOnMobile() {
        driver.manage().window().setSize(new Dimension(375, 812));
        driver.get("http://localhost:3000/checkout");

        percy.snapshot("Checkout Page - Mobile", List.of(
            new Percy.SnapshotOptions.Builder()
                .widths(List.of(375, 414))
                .build()
        ));
    }

    @AfterEach
    void tearDown() {
        driver.quit();
    }
}
```

### Chromatic + Storybook (CI Integration)

```yaml
# .github/workflows/visual-regression.yml
name: Visual Regression
on:
  push:
    branches: [main]
  pull_request:

jobs:
  chromatic:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Install dependencies
        run: npm ci

      - name: Build Storybook
        run: npm run build-storybook

      - name: Publish to Chromatic
        uses: chromaui/action@latest
        with:
          projectToken: ${{ secrets.CHROMATIC_PROJECT_TOKEN }}
          storybookBuildDir: storybook-static
          exitOnceUploaded: true
          onlyChanged: true
```

### Baseline Approval Workflow

```yaml
# .percy.yml
version: 2
snapshot:
  widths: [375, 1280]
  minHeight: 1024
  percyCSS: |
    /* Hide dynamic content like timestamps */
    .timestamp { display: none !important; }
discovery:
  allowedHostnames:
    - cdn.example.com
  networkIdleTimeout: 150
```

**Expert note**: Visual regression is expensive and flaky when tests include dynamic data (timestamps, random IDs, ads). Use `percyCSS` or data-testids to stabilise the DOM before snapshotting. Treat visual diffs as code reviews — never auto-approve.

---

## Quick Checklist: Is This a Good Test?

- [ ] Does it test BEHAVIOUR, not implementation?
- [ ] Can I understand what it tests by reading the name alone?
- [ ] Does it fail ONLY when the behaviour is wrong? (not when internals change)
- [ ] Does it have Given-When-Then structure?
- [ ] Is it independent of other tests?
- [ ] Does it cover an error path, not just happy path?
- [ ] Would a bug in the code be caught by this test?
