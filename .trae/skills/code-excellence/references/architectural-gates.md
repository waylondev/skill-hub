# Architectural Gates (MANDATORY)

## Purpose

This file defines the **mandatory architecture review gates** that AI MUST pass through BEFORE generating any code.
These are NOT suggestions — they are hard enforcement rules. If a gate fails, AI MUST redesign, NOT generate.

---

## Gate 0: Context Profile Determination

**Before any code generation**, determine the project context profile using [context-branching.md].

### Required Action

```
User request → Analyze signals:
  - Keywords: "MVP", "prototype", "startup" → Startup MVP (Profile 1)
  - Keywords: "production", "scale", "enterprise" → Enterprise (Profile 5-6)
  - No context signal → Assume Scale-Up (Profile 3) — safe middle ground
  - "legacy", "refactor" → Legacy Modernization (Profile 7)
```

### Enforcement

- **If context is ambiguous**: Ask the user. Do NOT assume.
- **If no context is provided**: Default to Scale-Up — include auth, observability, resilience.

---

## Gate 1: Layer Architecture Enforcement

**CRITICAL**: This is the #1 failure mode. AI consistently violates layer boundaries.

### Mandatory Layer Structure (Java/Spring)

```
┌─────────────────────────────────────────────────────────┐
│  Controller Layer (api/)                                │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Responsibilities:                                │  │
│  │  - HTTP mapping (@RestController, @GetMapping)   │  │
│  │  - Input validation (@Valid)                     │  │
│  │  - Header/cookie extraction                      │  │
│  │  - Return DTO (NOT domain objects)               │  │
│  │  - NO business logic                             │  │
│  │  - NO direct repository access                   │  │
│  │  - MUST NOT return @Entity                       │  │
│  └───────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────┤
│  Service Layer (service/)                               │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Responsibilities:                                │  │
│  │  - Business logic orchestration                  │  │
│  │  - Transaction boundaries (@Transactional)       │  │
│  │  - Call repository for data access               │  │
│  │  - Call domain objects for business rules        │  │
│  │  - Return DOMAIN OBJECTS (NOT DTOs)             │  │
│  │  - DTO mapping is Controller or Mapper's job     │  │
│  │  - NO HTTP types (HttpServletRequest, etc.)     │  │
│  │  - NO DTO construction in Service               │  │
│  └───────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────┤
│  Domain Layer (domain/)                                 │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Responsibilities:                                │  │
│  │  - Aggregate roots                               │  │
│  │  - Value objects                                 │  │
│  │  - Domain invariants (business rules)            │  │
│  │  - Domain events                                 │  │
│  │  - NO infrastructure concerns                    │  │
│  │  - NO JPA annotations on domain methods          │  │
│  │  - NO Spring annotations                         │  │
│  └───────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────┤
│  Repository Layer (repository/)                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Responsibilities:                                │  │
│  │  - Data access abstraction                       │  │
│  │  - JPA queries, projections                      │  │
│  │  - Return domain objects or DTO projections      │  │
│  │  - NO business logic                             │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Hard Rules (VIOLATION = REJECT + REDESIGN)

| Rule | Check | Violation Example |
|------|-------|-------------------|
| **Service MUST NOT return DTO** | Return type of `@Service` methods | `OrderResponse create(...)` — returns DTO |
| **Service MUST NOT import HTTP types** | No `HttpServletRequest`, `HttpServletResponse` in Service | `public Order create(HttpServletRequest req)` |
| **Controller MUST NOT access Repository directly** | No `@Autowired OrderRepository` in Controller | `private final OrderRepository orderRepo` in Controller |
| **Controller MUST NOT contain business logic** | No `if` with business meaning in Controller | `if (order.getStatus() == CANCELLED) ...` in Controller |
| **Service MUST NOT construct DTO** | No `new OrderResponse(...)` in Service | `return new OrderResponse(order.getId(), ...)` in Service |
| **Domain MUST NOT depend on Spring** | No `@Service`, `@Repository`, `@Autowired` in domain/ | `@Component public class Order { ... }` |
| **DTO MUST be in api/dto/** | DTO package location | `domain/OrderDto.java` |

### Compliant Pattern

```java
// Controller — returns DTO, calls Service, handles validation
@RestController
@RequestMapping("/api/v1/orders")
public class OrderController {
    private final OrderService orderService;
    private final OrderDtoMapper orderMapper;

    @PostMapping
    public OrderResponse create(
        @RequestHeader("Idempotency-Key") String idempotencyKey,
        @Valid @RequestBody CreateOrderRequest request) {
        Order order = orderService.create(request.toCommand(), idempotencyKey);
        return orderMapper.toResponse(order);
    }
}

// Service — returns domain object, NO DTO construction
@Service
public class OrderService {
    private final OrderRepository orderRepo;

    @Transactional
    public Order create(CreateOrderCommand cmd, String idempotencyKey) {
        // check idempotency
        Order existing = orderRepo.findByIdempotencyKey(idempotencyKey).orElse(null);
        if (existing != null) return existing;

        // build from command
        List<OrderItem> items = cmd.items().stream()
            .map(item -> new OrderItem(item.sku(), item.quantity(),
                new Money(item.unitPrice(), cmd.currency())))
            .toList();

        Order order = Order.create(cmd.userId(), items, cmd.currency(), idempotencyKey);
        return orderRepo.save(order);
    }
}

// Mapper — dedicated class for domain ↔ DTO conversion
@Component
public class OrderDtoMapper {
    public OrderResponse toResponse(Order order) {
        return new OrderResponse(
            order.getId(),
            order.getUserId(),
            order.getStatus().name(),
            new MoneyDto(order.getTotal().getAmount(), order.getTotal().getCurrency()),
            order.getItems().stream().map(this::toItemDto).toList(),
            order.getIdempotencyKey(),
            order.getCreatedAt(),
            order.getUpdatedAt()
        );
    }

    private OrderItemDto toItemDto(OrderItem item) {
        return new OrderItemDto(item.getSku(), item.getQuantity(),
            new MoneyDto(item.getUnitPrice().getAmount(), item.getUnitPrice().getCurrency()));
    }
}
```

### Enforcement Strategy

- **ArchUnit test** (MUST be generated with the project):
  ```java
  // Layer dependency rule
  classes().that().resideInAPackage("..service..")
      .should().onlyDependOnClassesThat()
      .resideInAnyPackage("..domain..", "..repository..", "java..", "org.springframework..")
      .because("Service layer must not depend on DTO or HTTP types");

  // DTO location rule
  classes().that().haveSimpleNameEndingWith("Response")
      .or().haveSimpleNameEndingWith("Request")
      .should().resideInAPackage("..api.dto..");

  // No Entity leak rule
  noClasses().that().areAnnotatedWith(Entity.class)
      .should().beReturnedFromMethod()
      .that().areDeclaredInClassesThat().areAnnotatedWith(RestController.class);
  ```

- **AI self-check** (before output): Scan every method in Service — if return type ends with "Response", "Dto", or "DTO" → **STOP, redesign**.

---

## Gate 2: TOCTOU Prevention Enforcement

**CRITICAL**: Check-then-act patterns are the #1 concurrency bug source.

### Hard Rule

Any pattern that follows this structure is **PROHIBITED**:

```java
// ❌ PROHIBITED — check and act are NOT atomic
if (checkCondition()) {
    performAction();
}
```

### Required Patterns (choose based on context)

| Pattern | When to Use | Implementation |
|---------|-------------|----------------|
| **DB Unique Constraint + Catch** | Idempotent creation | `try { save(); } catch (DataIntegrityViolationException) { return existing; }` |
| **Atomic UPSERT** | PostgreSQL | `INSERT ... ON CONFLICT DO NOTHING RETURNING *` |
| **SELECT ... FOR UPDATE** | Inventory deduction, balance deduction | Pessimistic lock within transaction |
| **Optimistic Locking** | Low-conflict concurrent updates | `@Version` field + retry on `OptimisticLockException` |
| **Distributed Lock** | Multi-node coordination | Redis `SETNX` + expiry, or ZooKeeper |

### Enforcement

- **AI self-check**: For every `if (...)` followed by a `save()` or `insert()` → flag and require atomic pattern.
- **ArchUnit + Integration test**: Concurrent request test verifying exactly-one creation.

---

## Gate 3: Idempotency Enforcement

### Hard Rule

All POST/PATCH endpoints that create or modify state **MUST** require an `Idempotency-Key` header.

### Prohibited Pattern

```java
// ❌ PROHIBITED — auto-generating UUID defeats the purpose
String key = idempotencyKey != null ? idempotencyKey : UUID.randomUUID().toString();
// Client retries get different keys → no deduplication → double charge
```

### Required Pattern

```java
// ✅ REQUIRED — header is mandatory, return 400 if missing
@PostMapping
public OrderResponse create(
    @RequestHeader("Idempotency-Key") @NotBlank String idempotencyKey,
    @Valid @RequestBody CreateOrderRequest request) {
    Order order = orderService.create(request.toCommand(), idempotencyKey);
    return orderMapper.toResponse(order);
}
```

### Exception (MUST be documented with comment)

```java
// WHY: No idempotency-key required — this is an internal admin endpoint
// with single-operator access and low call frequency.
// If traffic increases, idempotency must be added.
@PostMapping("/admin/orders/fix")
public OrderResponse fix(@Valid @RequestBody FixOrderRequest request) { ... }
```

### Enforcement

- **AI self-check**: Every `@PostMapping` — does it have `@RequestHeader("Idempotency-Key")`? If no → **STOP, redesign**.

---

## Gate 4: Security Entry Point Enforcement

### Hard Rule

All Spring Security error responses **MUST** use `authenticationEntryPoint` and `accessDeniedHandler`.
No unhandled security exceptions → no HTML error pages → no leaking stack traces.

### Required Pattern

```java
@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http.exceptionHandling(exceptions -> exceptions
        .authenticationEntryPoint((request, response, authException) -> {
            response.setStatus(401);
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.getWriter().write(
                "{\"code\":\"AUTH_FAILED\",\"message\":\"Authentication required\"}"
            );
        })
        .accessDeniedHandler((request, response, accessDeniedException) -> {
            response.setStatus(403);
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.getWriter().write(
                "{\"code\":\"ACCESS_DENIED\",\"message\":\"Insufficient permissions\"}"
            );
        })
    );
    // ... rest of config
    return http.build();
}
```

### Global Exception Handler Rules

| Exception | HTTP Status | Response Message | Must NOT Include |
|-----------|-------------|------------------|------------------|
| `AuthenticationException` | 401 | "Authentication required" | Username, token, roles |
| `AccessDeniedException` | 403 | "Insufficient permissions" | User details, resource path |
| `EntityNotFoundException` | 404 | "Resource not found: {id}" | SQL query, stack trace |
| `MethodArgumentNotValidException` | 400 | Field-level validation errors | Internal class names |
| `Exception` (catch-all) | 500 | "An unexpected error occurred" | Exception class, message, stack trace |

### Enforcement

- **AI self-check**: Does `SecurityConfig` have `.exceptionHandling(...)` with both handlers? If no → **STOP**.
- **AI self-check**: Does `@RestControllerAdvice` have a catch-all `Exception` handler that returns generic 500? If no → **STOP**.

---

## Gate 5: Aggregate Root Invariant Enforcement

### Hard Rule

All business invariants **MUST** be enforced within the aggregate root. Service layer calls aggregate methods, not repository methods.

### Prohibited Pattern

```java
// ❌ PROHIBITED — business logic in Service, Order is anemic data class
@Service
public class OrderService {
    public void cancel(Long orderId) {
        Order order = orderRepo.findById(orderId).orElseThrow();
        if (order.getStatus() == CANCELLED) throw ...;  // invariant check in Service
        if (order.getStatus() == SHIPPED) throw ...;    // invariant check in Service
        order.setStatus(CANCELLED);                      // direct field mutation
        orderRepo.save(order);
    }
}
```

### Required Pattern

```java
// ✅ REQUIRED — invariant in aggregate, Service calls domain method
@Entity
public class Order {
    public void cancel() {
        if (this.status == CANCELLED)
            throw new OrderAlreadyCancelledException(this.id);
        if (this.status == SHIPPED || this.status == DELIVERED)
            throw new InvalidOrderStateException(this.id, this.status, "cannot cancel");
        this.status = OrderStatus.CANCELLED;
        this.updatedAt = Instant.now();
    }
}

@Service
public class OrderService {
    public void cancel(Long orderId) {
        Order order = orderRepo.findByIdWithItems(orderId).orElseThrow();
        order.cancel();  // business logic executed by aggregate itself
        orderRepo.save(order);
    }
}
```

### Enforcement

- **AI self-check**: For every method in Service that contains `if` checking domain state → flag. Should the `if` be in the domain object?
- **ArchUnit test**: No classes in `..service..` should access setters of `@Entity` fields directly (use builder/factory methods only).

---

## Gate 6: Projection Query Enforcement

### Hard Rule

List/detail endpoints **MUST** use DTO projections, NOT load entities + map in Service.

### Prohibited Pattern

```java
// ❌ PROHIBITED — loads full entity + all relationships → N+1 risk
@Query("SELECT o FROM Order o WHERE o.userId = :userId")
List<Order> findByUserId(@Param("userId") Long userId);

// Service then maps to DTO — wastes DB bandwidth, memory, GC
```

### Required Pattern

```java
// ✅ REQUIRED — JPQL constructor expression, DB returns only needed columns
@Query("""
    SELECT new com.example.api.dto.OrderResponse(
        o.id, o.userId, CAST(o.status AS string),
        new MoneyDto(o.total.amount, o.total.currency),
        null, o.idempotencyKey, o.createdAt, o.updatedAt
    )
    FROM Order o WHERE o.userId = :userId
    """)
Page<OrderResponse> findByUserIdResponse(@Param("userId") Long userId, Pageable pageable);
```

### Enforcement

- **AI self-check**: Does the Repository have projection queries (SELECT new ...)? For list/detail endpoints, if only `findById` exists → **STOP, add projections**.
- **ArchUnit test**: Every `@RestController` GET method that returns a collection — the backing Repository method must return DTO/Projection, NOT Entity.

---

## Gate 7: Configuration Externalization Enforcement

### Hard Rule

Zero hardcoded values in source code. Every environment-dependent value uses `${ENV_VAR:default}`.

### Prohibited Values

| Pattern | Why Prohibited |
|---------|----------------|
| `"localhost"`, `"127.0.0.1"` | Fails in production |
| `"jdbc:postgresql://db-prod:5432/..."` | Environment-specific URL in code |
| `"sk-prod-..."`, `"api-key-..."` | Secret in source code |
| `30` (magic number timeout) | Cannot tune per environment |
| `"http://payment-service:8080"` | URL changes between environments |

### Required Pattern

```yaml
# application.yml
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:orders}
    username: ${DB_USER:postgres}
    password: ${DB_PASSWORD:postgres}

app:
  payment:
    url: ${PAYMENT_SERVICE_URL:http://localhost:8080}
    timeout-seconds: ${PAYMENT_TIMEOUT:10}
    max-retries: ${PAYMENT_RETRIES:3}
```

### Enforcement

- **AI self-check**: Scan all string literals — any contain `://`, `:`, or look like credentials? → externalize.
- **AI self-check**: Any `private static final int TIMEOUT = 30;` without `@Value` injection? → externalize.

---

## Pre-Generation Gate Checklist

AI MUST evaluate ALL 7 gates BEFORE generating code. If ANY gate fails, AI MUST redesign first.

| Gate | Name | Check |
|------|------|-------|
| G0 | Context Profile | Determined? (MVP/Scale-Up/Enterprise) |
| G1 | Layer Architecture | Service returns domain objects? Controller returns DTOs? Dedicated Mapper? |
| G2 | TOCTOU Prevention | No check-then-act? Atomic patterns used? |
| G3 | Idempotency | POST requires Idempotency-Key header? No auto-UUID fallback? |
| G4 | Security Entry Points | exceptionHandling configured? Global handler has catch-all? |
| G5 | Aggregate Invariants | Business rules in domain objects, not Service? |
| G6 | Projection Queries | List/detail endpoints use DTO projections? |
| G7 | Config Externalization | Zero hardcoded values? All env-dependent values use `${VAR:default}`? |

**Pass criteria**: ALL gates must pass. Any failure → redesign → re-evaluate gates → then generate.
