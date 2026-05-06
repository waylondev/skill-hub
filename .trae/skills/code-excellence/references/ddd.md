# Domain-Driven Design (DDD) — Expert Reference

## Purpose

This reference encodes DDD patterns for modeling complex business domains. Use when the system has rich business rules, multiple stakeholders with different domain languages, or a domain that will evolve significantly over time.

---

## Strategic Design

### Bounded Context

A Bounded Context is a semantic boundary within which a domain model is defined and applicable. Each context has its own ubiquitous language.

```
+------------------+     +------------------+     +------------------+
|   Order Context   |     | Payment Context   |     | Shipping Context |
|                   |     |                   |     |                  |
| Order             |────>| Payment           |────>| Shipment         |
| OrderLine         |     | Transaction       |     | Delivery         |
| OrderStatus       |     | Refund            |     | TrackingNumber   |
+------------------+     +------------------+     +------------------+
```

**Rules**:
- A concept (e.g., "Customer") can have different models in different contexts
- Cross-context communication uses explicit interfaces (ACL, Open Host Service)
- Never share a database schema across bounded contexts (each owns its data)

### Context Mapping

See `patterns-architecture.md` § Bounded Context Mapping for the 8 relationship patterns.

### Subdomain Classification

| Type | Definition | Strategy |
|------|-----------|----------|
| **Core Domain** | What makes your business unique | Invest heavily, custom implementation |
| **Supporting Domain** | Necessary but not differentiating | Build or buy, keep simple |
| **Generic Domain** | Standard problem (auth, billing, logging) | Buy/SaaS, don't reinvent |

---

## Tactical Design

### Aggregates

An Aggregate is a cluster of domain objects treated as a single unit for data changes. It has one **Aggregate Root** that enforces invariants.

```java
// Aggregate Root
public class Order {
    private final OrderId id;
    private final UserId userId;
    private OrderStatus status;
    private final List<OrderLine> lines; // Entity within aggregate
    private Money total;

    // Factory method — enforces creation invariants
    public static Order create(UserId userId, List<OrderLineItem> items, PricingService pricing) {
        var order = new Order(userId);
        for (var item : items) {
            order.addLine(item, pricing);
        }
        order.addDomainEvent(new OrderCreatedEvent(order.id(), order.total()));
        return order;
    }

    // Business behavior — enforces state transition invariants
    public void cancel(CancellationPolicy policy) {
        if (status != PENDING && status != CONFIRMED)
            throw new IllegalStateException("Only pending/confirmed orders can be cancelled");
        if (!policy.isCancellable(this))
            throw new NonCancellableOrderException(id);

        status = CANCELLED;
        addDomainEvent(new OrderCancelledEvent(id, Instant.now()));
    }

    // Encapsulation: no public setters
    // Internal state changes ONLY through business methods
}

// Entity within aggregate — no independent lifecycle
public class OrderLine {
    private final ProductId productId;
    private int quantity;
    private Money unitPrice;

    Money subtotal() { return unitPrice.multiply(quantity); }
}

// Value Object — immutable, identified by its attributes
public record OrderId(String value) {
    public OrderId {
        if (value == null || !value.matches("ORD-[0-9A-Z]{8}"))
            throw new IllegalArgumentException("Invalid OrderId format");
    }
}
```

**Aggregate Design Rules**:

| Rule | Rationale |
|------|-----------|
| Aggregate Root is the only entry point | Prevents invariant violations |
| No references to external Aggregate Roots by object — use IDs | Prevents cross-aggregate consistency traps |
| Keep aggregates small | Smaller = fewer concurrency conflicts, simpler transactions |
| Business invariants within one aggregate use synchronous transactions | Invariants spanning aggregates use eventual consistency |
| Aggregate method ≤ 30 lines | If longer, the aggregate is doing too much |

**Aggregate Size Decision**:

```
Start SMALL (single entity). Enlarge ONLY when:
1. A business invariant requires atomic validation of multiple entities
2. The entities always change together
3. Separate aggregates would cause unacceptable eventual consistency delays
```

### Value Objects

Value Objects are immutable objects defined by their attributes, not identity.

```java
// Java 21 record — inherently immutable
public record Money(BigDecimal amount, Currency currency) {
    public Money {
        if (amount.scale() > 2)
            throw new IllegalArgumentException("Money must have at most 2 decimal places");
        Objects.requireNonNull(currency);
    }

    public Money add(Money other) {
        if (!this.currency.equals(other.currency))
            throw new CurrencyMismatchException(this.currency, other.currency);
        return new Money(this.amount.add(other.amount), this.currency);
    }

    public Money multiply(int factor) {
        return new Money(amount.multiply(BigDecimal.valueOf(factor)), currency);
    }

    public boolean isGreaterThan(Money other) {
        return amount.compareTo(other.amount) > 0;
    }
}

// Address — Value Object
public record Address(
    String street, String city, String postalCode, Country country
) {
    public Address {
        Objects.requireNonNull(street); Objects.requireNonNull(city);
        Objects.requireNonNull(postalCode); Objects.requireNonNull(country);
    }
}
```

**Value Object Rules**:
- Must be immutable (final fields, no setters)
- Must validate in constructor (fail fast)
- Must implement `equals()` and `hashCode()` based on all attributes
- May contain behavior (e.g., `Money.add()`, `Address.isInRegion()`)

### Domain Events

Domain Events capture something that happened in the domain. They are immutable, past tense, and carry relevant data.

```java
// Domain Event — immutable, past tense
public record OrderCreatedEvent(
    OrderId orderId,
    UserId userId,
    Money total,
    Instant occurredAt,
    List<OrderLineSnapshot> lines
) implements DomainEvent {
    public OrderCreatedEvent {
        Objects.requireNonNull(orderId);
        Objects.requireNonNull(userId);
        Objects.requireNonNull(total);
        occurredAt = Objects.requireNonNullElse(occurredAt, Instant.now());
    }

    @Override public String aggregateId() { return orderId.value(); }
    @Override public String eventType() { return "order.created"; }
}

// Aggregate collects events during a transaction
public abstract class AggregateRoot {
    private final List<DomainEvent> events = new ArrayList<>();

    protected void addDomainEvent(DomainEvent event) {
        events.add(event);
    }

    public List<DomainEvent> getUncommittedEvents() {
        return List.copyOf(events);
    }

    public void markEventsAsCommitted() {
        events.clear();
    }
}
```

**Domain Event Rules**:
- Named in past tense: `OrderCreated`, `PaymentCaptured`, `ShipmentDelivered`
- Contains only data needed by consumers — no behavior
- Published after the aggregate is persisted (via Outbox pattern — see `patterns.md`)
- Consumers react asynchronously — never block the write operation

### Domain Services

Domain Services encapsulate business logic that doesn't naturally fit within an Entity or Value Object.

```java
// Domain Service — stateless, coordinates multiple aggregates
public class OrderPricingService {

    private final DiscountRepository discountRepo;
    private final TaxCalculator taxCalculator;

    public OrderPricingService(DiscountRepository discountRepo, TaxCalculator taxCalculator) {
        this.discountRepo = discountRepo;
        this.taxCalculator = taxCalculator;
    }

    public Money calculateTotal(List<OrderLineItem> items, UserId userId) {
        var subtotal = items.stream()
            .map(item -> item.price().multiply(item.quantity()))
            .reduce(Money.ZERO, Money::add);

        var discount = discountRepo.findApplicable(userId, subtotal);
        var afterDiscount = discount.apply(subtotal);
        var tax = taxCalculator.calculate(afterDiscount, items);

        return afterDiscount.add(tax);
    }
}
```

**Domain Service vs Application Service**:

| Aspect | Domain Service | Application Service |
|--------|---------------|---------------------|
| **Purpose** | Business logic that spans entities | Orchestration of use case flow |
| **State** | Stateless | Stateless (thin coordinator) |
| **Dependencies** | Domain repositories only | Application infrastructure (messaging, email, etc.) |
| **Transaction** | Doesn't manage | Manages transaction boundary |
| **Example** | `OrderPricingService` | `OrderApplicationService.createOrder()` |

### Repositories

Repositories provide collection-like access to aggregates. They are abstractions, not implementations.

```java
// Repository interface — in domain layer
public interface OrderRepository {
    Optional<Order> findById(OrderId id);
    void save(Order order); // handles both insert and update
    void delete(OrderId id);
    List<Order> findByUserId(UserId userId);
}

// Application Service — in application layer
@Service
@RequiredArgsConstructor
public class OrderApplicationService {
    private final OrderRepository orderRepo;
    private final DomainEventPublisher eventPublisher;

    @Transactional
    public OrderResult createOrder(CreateOrderCommand cmd) {
        var order = Order.create(cmd.userId(), cmd.items(), pricingService);
        orderRepo.save(order);
        eventPublisher.publish(order.getUncommittedEvents());
        order.markEventsAsCommitted();
        return new OrderResult(order.getId());
    }
}
```

**Repository Rules**:
- Repository interface lives in the **domain layer**
- Repository implementation lives in the **infrastructure layer**
- Only Aggregate Roots have repositories — entities within aggregates don't
- Methods return domain objects, not DTOs or JPA entities

---

## Domain Model Anti-Patterns

### AP-D1: Anemic Domain Model

**Symptom**: Domain objects are only getters/setters. All business logic is in service classes.

```java
// ❌ Anemic — no behavior, only data
public class Order {
    private OrderStatus status;
    private List<OrderLine> lines;
    public OrderStatus getStatus() { return status; }
    public void setStatus(OrderStatus status) { this.status = status; }
    public List<OrderLine> getLines() { return lines; }
    public void setLines(List<OrderLine> lines) { this.lines = lines; }
}

// Logic in service — procedural style
public class OrderService {
    public void cancelOrder(Order order) {
        if (order.getStatus() == OrderStatus.PENDING) {
            order.setStatus(OrderStatus.CANCELLED);
        }
    }
}
```

**Expert Fix**: Move behavior into domain objects.

```java
// ✅ Rich domain model
public class Order {
    private OrderStatus status;
    private List<OrderLine> lines;

    public void cancel() {
        if (status != PENDING)
            throw new IllegalStateException("Only pending orders can be cancelled");
        status = CANCELLED;
    }

    public void addLine(OrderLine line) {
        if (status != DRAFT)
            throw new IllegalStateException("Can only add lines to draft orders");
        lines.add(line);
    }

    // No setters — state changes through business methods only
}
```

### AP-D2: Primitive Obsession

**Symptom**: Domain concepts represented as primitives instead of Value Objects.

```java
// ❌ Primitive obsession
public class User {
    private String email;        // Could be any string
    private String phone;        // No validation
    private Long orderId;        // No type safety
}
```

**Expert Fix**: Wrap primitives in Value Objects.

```java
// ✅ Value Objects with validation
public record Email(String value) {
    public Email {
        if (!value.matches("^[\\w.-]+@[\\w.-]+\\.\\w{2,}$"))
            throw new IllegalArgumentException("Invalid email: " + value);
    }
}

public record OrderId(Long value) {
    public OrderId {
        if (value == null || value <= 0)
            throw new IllegalArgumentException("OrderId must be positive");
    }
}
```

### AP-D3: Aggregate That's Too Big

**Symptom**: Aggregate contains 5+ entity types, handles multiple business invariants, has > 300 lines.

```
Root Cause: Aggregating entities because they are "related", not because they share invariants.
```

**Expert Fix**: Split aggregates. Use IDs for cross-aggregate references. Use domain events for cross-aggregate consistency.

```
Before:
  Order Aggregate
  ├── Order (root)
  ├── OrderLine (entity)
  ├── Payment (entity)
  ├── Invoice (entity)
  └── Shipment (entity)

After:
  Order Aggregate (root + lines)     ← Transactional boundary: order + lines
  Payment Aggregate (root)           ← Transactional boundary: payment only
  Invoice Aggregate (root)           ← Triggered by OrderCreatedEvent
  Shipment Aggregate (root)          ← Triggered by PaymentCapturedEvent
```

### AP-D4: Domain Layer Depends on Infrastructure

**Symptom**: Domain model imports JPA annotations, Spring annotations, or JDBC classes.

```java
// ❌ Domain layer polluted with infrastructure
@Entity  // JPA — belongs to infrastructure
@Table(name = "orders")
public class Order {
    @Id  // Persistence concern leaking into domain
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)  // ORM concern
    private User user;
}
```

**Expert Fix**: Clean architecture. Domain is pure. Infrastructure implements domain interfaces.

```java
// Domain layer — pure Java
public class Order {
    private OrderId id;
    private UserId userId;
    // No imports from javax.persistence, org.springframework, etc.
}

// Infrastructure layer — JPA implementation
@Entity
@Table(name = "orders")
class JpaOrderEntity {
    @Id Long id;
    @Column(name = "user_id") Long userId;

    // Maps to/from domain object
    Order toDomain() { return new Order(new OrderId(id), new UserId(userId)); }
    static JpaOrderEntity fromDomain(Order order) { ... }
}
```

---

## DDD Quick Decision Guide

| Question | Decision |
|----------|----------|
| Does the domain have complex business rules? | Use DDD tactical patterns |
| Is it CRUD with simple validation? | Skip DDD — use Active Record or Transaction Script |
| Do multiple teams work on different parts of the domain? | Define Bounded Contexts per team |
| Is the domain stable and well-understood? | DDD is worth the investment |
| Is the domain exploratory/changing rapidly? | Start with Transaction Script, evolve to DDD |
| How to handle cross-aggregate consistency? | Domain events + eventual consistency |
| How to share data between Bounded Contexts? | Published Language or Anti-Corruption Layer |

---

## Quick Checklist

- [ ] Each Aggregate has one Root that enforces invariants?
- [ ] Value Objects are immutable with validation?
- [ ] Domain Events are past tense and carry relevant data?
- [ ] Repository interfaces are in domain layer, implementations in infrastructure?
- [ ] No JPA/Spring annotations in domain layer?
- [ ] No primitive obsession — domain concepts wrapped in Value Objects?
- [ ] Aggregate sizes are small (single entity or tightly-coupled cluster)?
- [ ] Cross-aggregate references use IDs, not object references?
- [ ] Business logic is in domain objects, not in service classes?
