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

## Quick Checklist: Is This a Good Test?

- [ ] Does it test BEHAVIOUR, not implementation?
- [ ] Can I understand what it tests by reading the name alone?
- [ ] Does it fail ONLY when the behaviour is wrong? (not when internals change)
- [ ] Does it have Given-When-Then structure?
- [ ] Is it independent of other tests?
- [ ] Does it cover an error path, not just happy path?
- [ ] Would a bug in the code be caught by this test?
